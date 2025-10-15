defmodule TrackUpstream.CLI do
  @moduledoc """
  User interface and main orchestration for upstream change tracking.
  """

  alias TrackUpstream.{
    Analysis,
    Config,
    FileMatcher,
    Git,
    OpenAI
  }

  @doc """
  Main entry point for the upstream tracker.
  """
  def run(plv_start_rev, plv_end_rev, lvn_start_rev, opts \\ []) do
    # Validate configuration
    Config.validate!()

    analyze = Keyword.get(opts, :analyze, false)
    upstream_dir = Keyword.get(opts, :upstream_dir)

    unless upstream_dir do
      IO.puts("Error: --upstream-dir is required")
      System.halt(1)
    end

    plv_dir = upstream_dir
    lvn_dir = "."

    IO.puts("Finding closest file matches...")
    IO.puts("Upstream: #{plv_start_rev} -> #{plv_end_rev} (in #{plv_dir})")
    IO.puts("Downstream: #{lvn_start_rev} (in #{lvn_dir})")
    IO.puts("")

    # Get list of Elixir files from both repos
    plv_start_files = Git.get_elixir_files(plv_dir, plv_start_rev)
    plv_end_files = Git.get_elixir_files(plv_dir, plv_end_rev)
    lvn_start_files = Git.get_elixir_files(lvn_dir, lvn_start_rev)

    # Identify newly added files in PLV
    plv_start_set = MapSet.new(plv_start_files)
    plv_end_set = MapSet.new(plv_end_files)
    newly_added_files = MapSet.difference(plv_end_set, plv_start_set) |> MapSet.to_list()

    IO.puts("Analyzing file similarities...")
    IO.puts("Upstream #{plv_start_rev} files: #{length(plv_start_files)}")
    IO.puts("Upstream #{plv_end_rev} files: #{length(plv_end_files)}")
    IO.puts("Newly added in upstream: #{length(newly_added_files)}")
    IO.puts("Downstream files: #{length(lvn_start_files)}")
    IO.puts("")

    # For each upstream start file, find the closest match
    IO.puts("Matching existing upstream files...")
    concurrency = Config.analysis_config().concurrency

    existing_results =
      plv_start_files
      |> Task.async_stream(
        fn plv_file ->
          FileMatcher.find_closest_match(
            plv_file,
            plv_dir,
            plv_start_rev,
            lvn_start_files,
            lvn_dir,
            lvn_start_rev
          )
        end,
        timeout: :infinity,
        max_concurrency: concurrency
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.filter(& &1)
      |> Enum.sort_by(fn {_plv, _lvn, similarity, _verification} -> -similarity end)

    # Build a set of downstream files already matched to existing upstream files
    already_matched_lvn_files =
      MapSet.new(existing_results, fn {_plv, lvn, _sim, _verification} -> lvn end)

    # For newly added files, try to find potential matches in downstream
    IO.puts("\nAnalyzing newly added upstream files...")

    new_file_results =
      newly_added_files
      |> Task.async_stream(
        fn plv_file ->
          FileMatcher.find_closest_match(
            plv_file,
            plv_dir,
            plv_end_rev,
            lvn_start_files,
            lvn_dir,
            lvn_start_rev
          )
        end,
        timeout: :infinity,
        max_concurrency: concurrency
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.filter(& &1)
      |> Enum.sort_by(fn {_plv, _lvn, similarity, _verification} -> -similarity end)

    threshold = Config.analysis_config().similarity_threshold

    # Categorize new files based on their matches
    new_with_claimed_match =
      Enum.filter(new_file_results, fn {_, lvn, sim, verification} ->
        is_translation =
          case verification do
            %{"is_translation" => false} -> false
            _ -> true
          end

        sim >= threshold and MapSet.member?(already_matched_lvn_files, lvn) and is_translation
      end)

    new_with_unclaimed_match =
      Enum.filter(new_file_results, fn {_, lvn, sim, verification} ->
        is_translation =
          case verification do
            %{"is_translation" => false} -> false
            _ -> true
          end

        sim >= threshold and not MapSet.member?(already_matched_lvn_files, lvn) and
          is_translation
      end)

    new_with_low_match =
      Enum.filter(new_file_results, fn {_, _, sim, _verification} -> sim < threshold end)

    new_no_match =
      newly_added_files -- Enum.map(new_file_results, fn {plv, _, _, _verification} -> plv end)

    # For claimed matches, find the original upstream file
    new_with_claimed_annotated =
      Enum.map(new_with_claimed_match, fn {new_plv, lvn, sim, verification} ->
        original_plv = Enum.find(existing_results, fn {_plv, lvn_file, _, _} -> lvn_file == lvn end)
        {new_plv, lvn, sim, verification, original_plv}
      end)

    # Filter out files that aren't actual translations or below 70% similarity
    existing_results_filtered =
      Enum.filter(existing_results, fn {_plv, _lvn, sim, verification} ->
        is_high_enough = sim >= threshold

        is_translation =
          case verification do
            %{"is_translation" => false} -> false
            _ -> true
          end

        is_high_enough and is_translation
      end)

    # Find newly added test files that test translated modules
    IO.puts("\nAnalyzing newly added test files for translated modules...")

    # Get list of translated lib files
    translated_lib_files =
      existing_results_filtered
      |> Enum.filter(fn {plv_file, _lvn, _sim, _ver} -> String.starts_with?(plv_file, "lib/") end)
      |> Enum.map(fn {plv_file, _lvn, _sim, _ver} -> plv_file end)

    # Get modules from translated lib files
    translated_modules =
      FileMatcher.get_modules_from_lib_files(plv_dir, plv_end_rev, translated_lib_files)

    # Check newly added test files (exclude e2e tests)
    new_test_files =
      newly_added_files
      |> Enum.filter(fn file ->
        String.starts_with?(file, "test/") and not String.starts_with?(file, "test/e2e/")
      end)

    new_tests_for_translated =
      new_test_files
      |> Task.async_stream(
        fn test_file ->
          case Git.get_file_content(plv_dir, plv_end_rev, test_file) do
            {:ok, content} ->
              IO.write(".")
              tested_modules = OpenAI.Chat.get_tested_modules(test_file, content)

              # Check if any tested module is in our translated set
              if Enum.any?(tested_modules, fn m -> MapSet.member?(translated_modules, m) end) do
                {test_file, tested_modules,
                 MapSet.intersection(MapSet.new(tested_modules), translated_modules)
                 |> MapSet.to_list()}
              else
                nil
              end

            _ ->
              nil
          end
        end,
        timeout: :infinity,
        max_concurrency: concurrency
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.filter(& &1)

    # Print results
    print_results(
      existing_results_filtered,
      new_with_claimed_annotated,
      new_tests_for_translated,
      new_with_unclaimed_match,
      new_with_low_match,
      new_no_match,
      newly_added_files,
      existing_results,
      plv_start_rev,
      plv_end_rev,
      lvn_start_rev
    )

    # Run detailed analysis if requested
    if analyze do
      IO.puts("")
      IO.puts("=" |> String.duplicate(80))
      IO.puts("DETAILED ANALYSIS PHASE")
      IO.puts("=" |> String.duplicate(80))
      IO.puts("")

      # Collect relevant newly added files for the addendum
      relevant_new_files =
        Enum.map(new_with_claimed_annotated, fn {new_plv, _lvn, _sim, _verification, _original} ->
          new_plv
        end) ++
          Enum.map(new_tests_for_translated, fn {test_file, _all_tested, _matching} ->
            test_file
          end)

      Analysis.run_detailed_analysis(
        plv_start_rev,
        plv_end_rev,
        lvn_start_rev,
        existing_results_filtered,
        relevant_new_files
      )
    end
  end

  # Private functions

  defp print_results(
         existing_results_filtered,
         new_with_claimed_annotated,
         new_tests_for_translated,
         new_with_unclaimed_match,
         new_with_low_match,
         new_no_match,
         newly_added_files,
         existing_results,
         _plv_start_rev,
         _plv_end_rev,
         _lvn_start_rev
       ) do
    IO.puts("")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("MATCHED FILE PAIRS (Existing)")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("")

    for {plv_file, lvn_file, similarity, verification} <- existing_results_filtered do
      verification_text =
        case verification do
          %{"is_translation" => true, "confidence" => conf} -> " ✓ Translation (#{conf})"
          nil -> ""
        end

      IO.puts(
        "#{plv_file}\t#{lvn_file}\t#{Float.round(similarity * 100, 2)}%#{verification_text}"
      )
    end

    IO.puts("")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("NEWLY ADDED UPSTREAM FILES - Likely Renames/Refactors")
    IO.puts("(Matches downstream files already matched to other upstream files)")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("")

    if Enum.empty?(new_with_claimed_annotated) do
      IO.puts("(none)")
    else
      for {new_plv, lvn, sim, verification, {old_plv, _, old_sim, _}} <-
            new_with_claimed_annotated do
        verification_text =
          case verification do
            %{"is_translation" => true, "confidence" => conf} -> " ✓ Translation (#{conf})"
            %{"is_translation" => false, "reason" => reason} -> " ✗ Not translation (#{reason})"
            nil -> ""
          end

        IO.puts("NEW: #{new_plv}\t#{Float.round(sim * 100, 2)}%#{verification_text}")
        IO.puts("  -> DOWNSTREAM: #{lvn}")
        IO.puts("  -> OLD: #{old_plv}\t#{Float.round(old_sim * 100, 2)}%")
        IO.puts("")
      end
    end

    IO.puts("=" |> String.duplicate(80))
    IO.puts("NEWLY ADDED UPSTREAM FILES - Tests for Translated Modules")
    IO.puts("(New test files that test modules which have been translated)")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("")

    if Enum.empty?(new_tests_for_translated) do
      IO.puts("(none)")
    else
      for {test_file, _all_tested, matching_modules} <- new_tests_for_translated do
        IO.puts("#{test_file}")
        IO.puts("  Tests translated modules: #{Enum.join(matching_modules, ", ")}")
        IO.puts("")
      end
    end

    IO.puts("=" |> String.duplicate(80))
    IO.puts("NEWLY ADDED UPSTREAM FILES - Potentially Need Downstream Equivalent")
    IO.puts("(Matches unclaimed downstream files - may indicate downstream already has it)")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("")

    if Enum.empty?(new_with_unclaimed_match) do
      IO.puts("(none)")
    else
      for {plv_file, lvn_file, similarity, verification} <- new_with_unclaimed_match do
        verification_text =
          case verification do
            %{"is_translation" => true, "confidence" => conf} -> " ✓ Translation (#{conf})"
            %{"is_translation" => false, "reason" => reason} -> " ✗ Not translation (#{reason})"
            nil -> ""
          end

        IO.puts(
          "#{plv_file}\t#{lvn_file}\t#{Float.round(similarity * 100, 2)}%#{verification_text}"
        )
      end
    end

    # Count files that need porting (weak matches + no matches)
    files_needing_porting = length(new_with_low_match) + length(new_no_match)

    IO.puts("")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("NEWLY ADDED UPSTREAM FILES - Need Manual Review")
    IO.puts("(#{files_needing_porting} files with <70% similarity - likely need new implementation)")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("")
    IO.puts("(not shown - use git to review newly added files)")

    IO.puts("")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("SUMMARY")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("Existing file matches (≥70%, verified translations): #{length(existing_results_filtered)}")
    filtered_count = length(existing_results) - length(existing_results_filtered)

    if filtered_count > 0 do
      IO.puts("  (#{filtered_count} matches filtered out: <70% similarity or non-translations)")
    end

    IO.puts("")
    IO.puts("Newly added upstream files: #{length(newly_added_files)}")
    IO.puts("  - Likely renames/refactors: #{length(new_with_claimed_annotated)}")
    IO.puts("  - Tests for translated modules: #{length(new_tests_for_translated)}")
    IO.puts("  - Potentially need downstream equivalent: #{length(new_with_unclaimed_match)}")
    IO.puts("  - Need manual review (<70%): #{files_needing_porting}")
  end
end
