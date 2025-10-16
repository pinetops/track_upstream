defmodule TrackUpstream.GuideBuilder do
  @moduledoc """
  Build global translation guide from individual analyses.
  """

  alias TrackUpstream.{Config, Git, OpenAI}

  @doc """
  Build the global porting guide from individual analyses.
  """
  def build_global_guide(
        analyses,
        plv_start_rev,
        plv_end_rev,
        lvn_start_rev,
        newly_added_files,
        plv_dir
      ) do
    """
    # Phoenix LiveView → LiveView Native: Upstream Porting Guide

    **Generated:** #{DateTime.utc_now() |> DateTime.to_string()}
    **Baseline:** PLV #{plv_start_rev} → LVN #{lvn_start_rev}
    **Upstream Delta:** PLV #{plv_start_rev} → #{plv_end_rev}
    **Files Analyzed:** #{length(analyses)}
    **Relevant New Files:** #{length(newly_added_files)} (renames/refactors + tests for translated modules)

    ---

    ## Purpose

    **TASK:** Upgrade the current version of LiveView Native to incorporate recent changes to Phoenix LiveView, of which it is a derivative.

    **CURRENT STATE:**
    - The Phoenix LiveView dependency has already been updated, causing existing test failures
    - Run `mix test` to see current failures and prioritize changes based on impact

    #{Config.porting_constraints()}

    This guide documents:
    - **Baseline transformation:** How Phoenix LiveView code was originally adapted to LiveView Native (PLV #{plv_start_rev} → LVN #{lvn_start_rev})
    - **Upstream delta:** What changed in Phoenix LiveView that needs porting (PLV #{plv_start_rev} → #{plv_end_rev})
    - **Newly added files:** Descriptions of files added in Phoenix LiveView to help determine relevance (see Addendum)

    **Use this guide to:**
    1. Understand the transformation patterns (PLV → LVN)
    2. Apply those patterns to upstream changes
    3. Identify which newly added files are relevant for LiveView Native

    ---

    ## Project-Global Transformation Rules

    These rules appear across multiple files and represent the core mechanical transformations from Phoenix LiveView to LiveView Native.

    **Apply these rules when porting upstream changes.**

    #{extract_global_rules(analyses)}

    ---

    ## File-Specific Porting Guides

    Each section below shows:
    - **Baseline transformation rules** for that file (PLV #{plv_start_rev} → LVN #{lvn_start_rev})
    - **Upstream delta** for that file (PLV #{plv_start_rev} → #{plv_end_rev})
    - **Porting guidance** specific to that file

    #{build_file_specific_sections(analyses)}

    ---

    ## Statistics

    #{extract_key_insights(analyses)}

    ---

    ## Workflow for Porting

    **SCOPE:** You must systematically review and port ALL upstream changes from ALL #{length(analyses)}
    file pairs documented in this guide. Passing tests is necessary but not sufficient - there may be
    improvements, optimizations, and new features that don't affect current tests but should still be ported.

    **Goal:** Port all upstream changes in a series of logical updates, fixing test failures and ensuring
    no new failures are introduced at each step.

    **IMPORTANT:** The Phoenix LiveView dependency has already been updated, so `mix test` will show existing
    failures. These failures help you PRIORITIZE THE ORDER of porting work, but you will port ALL changes
    documented in this guide, not just the ones that fix tests.

    **Recommended Approach:**

    1. **Assess current state** - Run `mix test` to see existing failures. These failures help you PRIORITIZE
       THE ORDER of porting work, but you will port ALL changes, not just the ones that fix tests.

    2. **Understand the baseline** - Review project-global and file-global transformation rules

    3. **Examine the upstream delta** - See what changed in Phoenix LiveView

    4. **Review newly added files** - Check the Addendum for descriptions of new files

    5. **Create implementation plan** - Create a step for EACH of the #{length(analyses)} file pairs below.
       For each file:
       - Review its "FILE-GLOBAL TRANSFORMATION RULES"
       - Review ALL items in its "UPSTREAM DELTA" section
       - Create a substep to port each upstream delta (unless not applicable - see below)
       - Order the #{length(analyses)} files by impact on test failures (highest impact first)

       Your plan must have at least #{length(analyses)} steps, one per file pair. For each upstream delta,
       you must either:
       - **Port it** - Apply the transformation rules to port the change to LVN
       - **Exclude it** - Document why it's not applicable (e.g., CSS/JS exclusions per constraints,
         web-specific functionality, already implemented differently in LVN, etc.)

       IMPORTANT: Some changes may not be applicable to LiveView Native, but there must be an EXPLICIT
       DETERMINATION for each upstream delta with a clear explanation of why it was ported or excluded.

    6. **Execute steps with subagents (LINEAR - NO PARALLELISM):**
       - Execute steps ONE AT A TIME in sequential order
       - Do NOT run multiple steps in parallel
       - For each step:
         a. Create a dedicated subagent for that step only
         b. Provide the subagent with:
            * Instructions to load this complete porting guide (UPSTREAM_PORTING_GUIDE.md)
            * Details of all the steps
            * The specific step number this agent is tasked with
            * Instructions to focus ONLY on that step
         c. The subagent should:
            * Read the relevant sections of this guide
            * Apply the transformation rules to the specific changes
            * For EACH upstream delta: either port it OR document why it's not applicable
            * Make the code changes
            * Run tests - if they fail, FIX THEM (test failures are expected during porting)
            * Fix any compilation errors or warnings
            * Verify no NEW test failures unrelated to this step
            * **COMMIT THE CHANGES** using git with a descriptive commit message
            * Report completion with test results
            * If the APPROACH is wrong (wrong order, need different prereqs, etc), report that issue
         d. Wait for the subagent to complete and verify success
         e. Only then proceed to the next step
       - Each step builds on previous steps, so order matters

    7. **Handle unique cases** - Review unique semantic changes that don't follow rules

    8. **Validate completeness** - Review ALL #{length(analyses)} "UPSTREAM DELTA" sections and verify:
       ☐ Each upstream delta was either ported OR explicitly excluded (with reason)
       ☐ All tests pass
       ☐ No new compilation warnings
       ☐ Review the Addendum for newly added files - determine if any are relevant

       If ANY upstream delta was not addressed, return to step 5 and add it.

    ## Common Mistakes to Avoid

    ❌ **Stopping when tests pass** - Tests only validate critical paths, not all functionality
    ❌ **Only fixing breaking changes** - You must port improvements/features too
    ❌ **Skipping files without test failures** - They may have new features worth porting
    ❌ **Assuming all changes apply** - Some may not be applicable, but you must explicitly determine this
    ✅ **Systematically work through all #{length(analyses)} file pairs**
    ✅ **Port ALL upstream deltas unless explicitly excluded by constraints or explicitly determined not applicable**
    ✅ **Document your reasoning for any exclusions or non-applicable changes**

    **Example Subagent Prompt:**
    ```
    Task: Complete step X of #{length(analyses)}: [FILE PAIR] of the LiveView Native upgrade

    Context: Read UPSTREAM_PORTING_GUIDE.md section X for this file pair.

    Current State: The Phoenix LiveView dependency has been updated, causing test failures.
    Run `mix test` first to see which tests are currently failing.

    This file has [N] upstream deltas documented. You must address ALL of them.

    Upstream deltas for this file (from the guide):
    1. [specific delta from guide]
    2. [specific delta from guide]
    ...

    For each delta, either:
    - Port it to LVN (apply transformation rules from the guide)
    - Document why it's not applicable (e.g., CSS/JS per constraints, web-specific,
      already implemented differently in LVN, etc.)

    Requirements:
    - Address ALL upstream deltas for this file pair
    - Use transformation rules from the guide
    - Follow the CONSTRAINTS in the guide (see top of UPSTREAM_PORTING_GUIDE.md)
    - Run tests and FIX any failures (test failures during porting are expected - fix them!)
    - Ensure no NEW test failures unrelated to this step
    - Clear all compilation errors and warnings
    - **COMMIT your changes** with a descriptive commit message before reporting completion
    - Do NOT make changes for other file pairs

    IMPORTANT: Test failures are EXPECTED during porting. Your job is to FIX them, not abort.
    Only stop if the APPROACH is wrong (wrong order, missing prereqs, need to rethink strategy).

    Available Resources:
    - Porting guide: UPSTREAM_PORTING_GUIDE.md (in current directory)
    - Phoenix LiveView repo: ../phoenix_live_view
    - To view Phoenix LiveView files at specific revisions:
      * #{plv_start_rev} (baseline): git -C ../phoenix_live_view show #{plv_start_rev}:path/to/file
      * #{plv_end_rev} (target): git -C ../phoenix_live_view show #{plv_end_rev}:path/to/file
    - Current LiveView Native files: in current directory

    When you need more context than provided in the guide diffs, read the full
    Phoenix LiveView files using the git commands above.

    Report when complete with:
    - Summary of what was ported for each delta
    - Any exclusions/non-applicable changes with justification
    - Test results: which tests were fixed, any remaining test failures
    - Confirmation that no new unrelated test failures were introduced
    - **Confirmation that changes were committed** with the commit message

    If the APPROACH is wrong (not just test failures), report:
    - Why this step should not be done now
    - What prerequisite work is needed first
    - Which step should be attempted instead
    - No need to restore changes unless explicitly asked
    ```

    ---

    ## Addendum: Newly Added Files

    #{build_newly_added_files_section(newly_added_files, plv_dir, plv_end_rev)}

    """
  end

  # Private functions

  defp build_file_specific_sections(analyses) do
    analyses
    |> Enum.with_index(1)
    |> Enum.map(fn {{plv_file, lvn_file, similarity, analysis}, idx} ->
      """
      ### #{idx}. #{plv_file} → #{lvn_file}

      **Similarity:** #{Float.round(similarity * 100, 2)}%

      #{analysis}

      ---
      """
    end)
    |> Enum.join("\n")
  end

  defp extract_global_rules(analyses) do
    # Use LLM to extract project-global rules from all file-global rules
    api_key = System.get_env("OPENAI_API_KEY")
    unless api_key, do: raise "OPENAI_API_KEY not set"

    config = Config.openai_config()

    # Collect all file-global rules from individual analyses
    all_analyses_text =
      analyses
      |> Enum.map(fn {plv_file, lvn_file, _sim, analysis} ->
        """
        File: #{plv_file} → #{lvn_file}
        #{analysis}
        ---
        """
      end)
      |> Enum.join("\n")

    prompt = """
    TASK: You are helping upgrade LiveView Native to incorporate recent changes to Phoenix LiveView, of which it is a derivative.

    CURRENT STATE:
    - The Phoenix LiveView dependency has already been updated, causing existing test failures
    - Changes should prioritize fixing these test failures
    - Changes should be made in logical steps
    - After each step: ensure no NEW test failures and tests related to the step should pass

    #{Config.porting_constraints()}

    You are analyzing #{length(analyses)} file pair analyses to extract PROJECT-GLOBAL transformation rules.

    Each analysis contains FILE-GLOBAL rules. Your job is to identify rules that appear across MULTIPLE files and consolidate them into PROJECT-GLOBAL rules.

    All individual analyses:
    #{String.slice(all_analyses_text, 0, 50000)}

    Task: Extract PROJECT-GLOBAL transformation rules that appear in multiple files.

    For each project-global rule, provide:
    1. Rule name and pattern (e.g., "Module Namespace Transformation: Phoenix.LiveView → LiveViewNative")
    2. How many files this rule appears in
    3. Brief description of the pattern
    4. 1-2 examples from different files
    5. Any special considerations for this rule (referencing the CONSTRAINTS above when relevant)

    Format as markdown with clear sections.
    """

    response =
      Req.post!(
        "https://api.openai.com/v1/chat/completions",
        json: %{
          model: config.analysis_model,
          messages: [%{role: "user", content: prompt}],
          temperature: 0
        },
        headers: [{"Authorization", "Bearer #{api_key}"}],
        retry: :transient,
        receive_timeout: config.timeout
      )

    case response.status do
      200 ->
        response.body["choices"] |> List.first() |> Map.get("message") |> Map.get("content")

      _ ->
        """
        _Error extracting project-global rules from #{length(analyses)} analyses._

        Failed to analyze common patterns. See individual file analyses below.
        """
    end
  end

  defp extract_key_insights(analyses) do
    """
    - **Total file pairs analyzed:** #{length(analyses)}
    - **Average similarity:** #{calculate_average_similarity(analyses)}%
    - **Individual analyses:** See sections above for complete details
    """
  end

  defp calculate_average_similarity(analyses) do
    if length(analyses) > 0 do
      total = Enum.reduce(analyses, 0.0, fn {_, _, sim, _}, acc -> acc + sim end)
      Float.round(total / length(analyses) * 100, 2)
    else
      0.0
    end
  end

  defp build_newly_added_files_section(newly_added_files, plv_dir, plv_end_rev) do
    if Enum.empty?(newly_added_files) do
      "_No relevant new files were added in this Phoenix LiveView update._"
    else
      """
      The following files were newly added in Phoenix LiveView #{plv_end_rev}. These include:
      1. **Likely renames/refactors** - New files that match existing LVN files already matched to other PLV files
      2. **Tests for translated modules** - New test files that test modules which have been translated to LVN

      Descriptions are provided to help determine when the actual content is relevant for porting to LiveView Native.

      **Files included:** #{length(newly_added_files)}

      #{build_file_descriptions(newly_added_files, plv_dir, plv_end_rev)}
      """
    end
  end

  defp build_file_descriptions(files, plv_dir, plv_rev) do
    IO.puts("Generating descriptions for #{length(files)} newly added files...")

    files
    |> Enum.with_index(1)
    |> Enum.map(fn {file, idx} ->
      IO.puts("  [#{idx}/#{length(files)}] Describing: #{file}")

      case Git.get_file_content(plv_dir, plv_rev, file) do
        {:ok, content} ->
          description = OpenAI.Chat.generate_file_description(file, content)

          """
          ### #{idx}. `#{file}`

          #{description}

          ---
          """

        :error ->
          """
          ### #{idx}. `#{file}`

          _Could not read file content_

          ---
          """
      end
    end)
    |> Enum.join("\n")
  end
end
