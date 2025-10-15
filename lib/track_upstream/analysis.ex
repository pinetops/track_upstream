defmodule TrackUpstream.Analysis do
  @moduledoc """
  Detailed analysis orchestration for file pairs.
  """

  alias TrackUpstream.{FilePairAnalyzer, Git, GuideBuilder, OpenAI}

  @doc """
  Run detailed analysis on all file pairs using GPT-4o.
  """
  def run_detailed_analysis(
        plv_start_rev,
        plv_end_rev,
        lvn_start_rev,
        file_pairs,
        newly_added_files
      ) do
    plv_dir = "../phoenix_live_view"

    # Filter to only pairs where PLV source has changed
    IO.puts(
      "Checking which PLV files have changed between #{plv_start_rev} and #{plv_end_rev}..."
    )

    changed_pairs =
      file_pairs
      |> Enum.filter(fn {plv_file, _lvn_file, _sim, _ver} ->
        Git.has_changes?(plv_dir, plv_start_rev, plv_end_rev, plv_file)
      end)

    filtered_count = length(file_pairs) - length(changed_pairs)

    IO.puts("Found #{length(changed_pairs)} file pairs with upstream changes")

    if filtered_count > 0 do
      IO.puts("Skipped #{filtered_count} pairs with no upstream changes")
    end

    IO.puts("")

    if Enum.empty?(changed_pairs) do
      IO.puts("No file pairs have upstream changes to analyze.")
      :ok
    else
      IO.puts("Analyzing #{length(changed_pairs)} file pairs with GPT-4o...")
      IO.puts("")

      # Create output directory
      output_dir = "translation_analyses"
      File.mkdir_p!(output_dir)

      # Analyze each file pair
      analyses =
        changed_pairs
        |> Enum.with_index(1)
        |> Enum.map(fn {{plv_file, lvn_file, similarity, _verification}, idx} ->
          IO.puts(
            "[#{idx}/#{length(changed_pairs)}] Analyzing: #{plv_file} -> #{lvn_file}"
          )

          # Get the actual diffs
          diff_output =
            FilePairAnalyzer.analyze_file_pair(
              plv_start_rev,
              plv_end_rev,
              lvn_start_rev,
              plv_file,
              lvn_file
            )

          # Call analysis agent
          prompt = """
          Analyze this PLV/LVN file pair to document the baseline transformation and upstream delta:

          **File Pair:**
          - PLV file: #{plv_file}
          - LVN file: #{lvn_file}
          - Similarity: #{Float.round(similarity * 100, 2)}%

          **Revisions:**
          - PLV start: #{plv_start_rev}
          - PLV end: #{plv_end_rev}
          - LVN start: #{lvn_start_rev}

          **Diffs:**

          The output below contains three diffs:
          1. DIFF 1 (PLV #{plv_start_rev} → #{plv_end_rev}): UPSTREAM DELTA - changes that need porting
          2. DIFF 2 (PLV #{plv_start_rev} → LVN #{lvn_start_rev}): BASELINE TRANSFORMATION - how code was adapted
          3. DIFF 3 (LVN #{lvn_start_rev} → working dir): Work in progress (if any)

          #{diff_output}

          **Your task:**
          Analyze these diffs and provide a structured analysis showing:
          1. How the code was transformed from PLV to LVN (DIFF 2) - extract transformation rules
          2. What changed upstream in PLV (DIFF 1) - format for LLM consumption
          3. Guidance on applying the transformation rules to the upstream changes
          """

          analysis = OpenAI.Chat.call_analysis_agent(prompt)

          # Save individual analysis
          safe_filename = String.replace(plv_file, "/", "_")
          File.write!(Path.join(output_dir, "#{safe_filename}.md"), analysis)

          {plv_file, lvn_file, similarity, analysis}
        end)

      IO.puts("")
      IO.puts("Individual analyses saved to #{output_dir}/")
      IO.puts("")

      # Build global translation guide
      IO.puts("Building global translation guide...")

      global_guide =
        GuideBuilder.build_global_guide(
          analyses,
          plv_start_rev,
          plv_end_rev,
          lvn_start_rev,
          newly_added_files,
          plv_dir
        )

      # Save global guide
      guide_path = "UPSTREAM_PORTING_GUIDE.md"
      File.write!(guide_path, global_guide)

      IO.puts("")
      IO.puts("=" |> String.duplicate(80))
      IO.puts("Analysis complete!")
      IO.puts("=" |> String.duplicate(80))
      IO.puts("Individual analyses: #{output_dir}/")
      IO.puts("Global guide: #{guide_path}")
    end
  end
end
