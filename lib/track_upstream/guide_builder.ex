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
    - ALL test failures (pre-existing from the dependency update AND any new failures) MUST be fixed
    - Run `mix test` to see current failures - these indicate what needs to be ported first

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

    ## File-Specific Porting Details

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

    **GOAL:** Fix ALL test failures and port ALL upstream changes in a series of logical steps.

    **COMPLETION CRITERIA - ALL MUST BE MET:**
    1. ✅ ALL tests pass (`mix test` shows 0 failures)
    2. ✅ ALL upstream deltas ported or explicitly excluded with justification
    3. ✅ No compilation errors or warnings
    4. ✅ All changes committed with descriptive messages

    **There are NO "separate issues" or "architectural differences" - all failures must be resolved.**

    **TEST FAILURE EXPECTATIONS:**
    - The Phoenix LiveView dependency has already been updated, causing pre-existing test failures
    - These pre-existing failures are NOT out of scope - they MUST be fixed as part of this migration
    - Pre-existing test failures indicate which changes are most critical to port first
    - After each step: ALL related test failures should be fixed, and NO new failures should be introduced
    - If test failures remain after porting all deltas, investigate and fix the root cause
    - Adapt the implementation to work with LVN's architecture - don't declare it "impossible"

    **Recommended Approach:**

    1. **Assess current state** - Run `mix test` to see pre-existing failures from the dependency update.
       These failures indicate which upstream changes are most critical and should be ported first.
       ALL of these failures MUST be fixed - they are part of the migration scope, not optional.

    2. **Understand the baseline** - Review project-global and file-global transformation rules

    3. **Examine the upstream delta** - See what changed in Phoenix LiveView

    4. **Review newly added files** - Check the Addendum for descriptions of new files

    5. **Identify what upstream changed conceptually, then map to files**:

       ⚠️ **CRITICAL: DO NOT START BY LOOKING AT FILES**
       ⚠️ **You must understand CONCEPTS first, then map concepts to files**

       **Step 5.1: Read and understand the PURPOSE of upstream changes**

       Go through each file's UPSTREAM DELTA section and ask: "WHY did upstream make this change?
       What problem were they solving? What feature were they adding?"

       DO NOT write "File X has changes to function Y"
       INSTEAD write "Upstream added [FEATURE/FIX] because [REASON]"

       Example - reading section 1 (html_engine.ex):
       - ❌ WRONG: "File has new annotate_slot callback"
       - ✅ RIGHT: "Upstream added slot annotation system to enable better debugging/tooling"

       Read ALL sections and for each one write down:
       - What conceptual change this represents
       - Why upstream made this change
       - What problem it solves or capability it adds

       **Step 5.2: Group conceptual changes that are related**

       Now look at your list of conceptual changes and group related ones:

       Example:
       ```
       Conceptual Change #1: "Slot annotation debugging system"
       - Enables tools to understand slot usage
       - Requires: callback definition + usage in rendering
       Files affected: html_engine (defines), js (uses)

       Conceptual Change #2: "Upload timeout handling"
       - Fixes issue where uploads could hang indefinitely
       - Requires: timeout tracking + propagation + tests
       Files affected: upload_client, client_proxy, tests

       Conceptual Change #3: "TreeDOM diff rendering"
       - Improves test failure messages for native markup
       - Requires: diff algorithm + test helper updates
       Files affected: view_tree, live_view_test
       ```

       **Step 5.3: Create tasks from conceptual changes**

       ❌ **WRONG - starting from files:**
       ```
       Step 1: Port file 9 (critical - has compilation error)
       Step 2: Port files 11, 10, 5 (test infrastructure)
       Step 3: Port files 1, 7, 8 (test files)
       ```
       This is file-driven thinking and fragments upstream work.

       ✅ **CORRECT - starting from concepts:**
       ```
       Task 1: Implement slot annotation debugging system
         Purpose: Enable tooling to understand slot usage in templates
         Why upstream made this: Better developer experience, debugging
         Files needed:
         - Section 9: html_engine (define callback)
         - Section 3: js (use in rendering)
         Expected outcome: Compilation warning fixed, slots can be annotated

       Task 2: Improve native markup diff rendering
         Purpose: Better test failure messages for TreeDOM
         Why upstream made this: Easier debugging of test failures
         Files needed:
         - Section 11: view_tree (diff algorithm)
         - Section 10: live_view_test (integrate diffing)
         Expected outcome: Test failures show clear diffs

       Task 3: Fix upload timeout handling
         Purpose: Prevent uploads from hanging indefinitely
         Why upstream made this: Production reliability
         Files needed:
         - Sections X, Y, Z (upload-related files)
         Expected outcome: Upload tests pass with timeout behavior
       ```

       Your plan MUST:
       - Start by listing conceptual changes (WHAT and WHY)
       - Then map concepts to files (not files to concepts)
       - Have task names that describe PURPOSE, not files
       - Show you understand WHY upstream made each change

       For each upstream delta in each task, you must either:
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
            * Report completion with test results
            * If the APPROACH is wrong (wrong order, need different prereqs, etc), report that issue
         d. **COMMIT THE CHANGES** - This is MANDATORY after completing each step:
            * Use git to commit with a clear, descriptive commit message
            * Commit message should describe WHAT changed and WHY (from a normal dev perspective)
            * DO NOT reference the migration guide, sections, deltas, or tasks in commit messages
            * Write as if explaining the change to someone without access to the porting guide
            * Example: "Add support for slot annotations in rendering engine" NOT "Port section 9 delta 3"
            * Example: "Fix upload timeout handling" NOT "Complete Task 2 from migration guide"
            * DO NOT proceed to the next step without committing
         e. Wait for the subagent to complete and verify success
         f. **REVISE THE PLAN if new information emerges:**
            * If tests still fail after completing a step, the plan may be incomplete
            * If you discover additional related changes that weren't grouped together, revise
            * Add new tasks or reorganize existing tasks as needed
            * Document why the plan was revised
         g. Only then proceed to the next step
       - Each step builds on previous steps, so order matters
       - **CRITICAL:** Every step MUST end with a git commit before moving to the next step
       - **ADAPTIVE:** Revise the plan when new information shows it's incomplete or wrong

    7. **Validate completeness** - Review ALL functional tasks and verify:
       ☐ Each task has been completed
       ☐ Each upstream delta across all #{length(analyses)} files was either ported OR explicitly excluded (with reason)
       ☐ ALL tests pass (0 failures) - see COMPLETION CRITERIA above
       ☐ No compilation errors or warnings
       ☐ Review the Addendum for newly added files - determine if any are relevant

       **If ANY criterion is not met:**
       - Return to step 5 and revise/add tasks
       - Investigate root causes of remaining failures
       - Do NOT declare completion with "separate issues" remaining
       - The migration is ONLY complete when ALL completion criteria are met

    ## Common Mistakes to Avoid

    ❌ **Declaring issues as "separate" or "architectural differences"** - ALL failures must be resolved
    ❌ **Not committing after each step** - Every step MUST end with a git commit
    ❌ **Assuming pre-existing test failures are out of scope** - They MUST be fixed as part of migration
    ❌ **Stopping when tests pass** - Tests only validate critical paths, not all functionality
    ❌ **Only fixing breaking changes** - You must port improvements/features too
    ❌ **Working file-by-file without considering related changes** - Use functional tasks that span files
    ❌ **Assuming all changes apply** - Some may not be applicable, but you must explicitly determine this
    ❌ **Sticking to the plan when new information shows it's wrong** - Revise the plan as needed
    ✅ **Resolve ALL failures - no "separate issues" allowed**
    ✅ **Revise the plan when tests still fail after completing tasks**
    ✅ **COMMIT after completing each step with a descriptive message**
    ✅ **FIX ALL test failures - pre-existing (from dependency update) and new ones**
    ✅ **Systematically work through all functional tasks**
    ✅ **Port ALL upstream deltas unless explicitly excluded by constraints or explicitly determined not applicable**
    ✅ **Document your reasoning for any exclusions or non-applicable changes**

    **Example Subagent Prompt:**
    ```
    Task: Complete task X: [DESCRIPTIVE TASK NAME] of the LiveView Native upgrade

    Context: This task implements [feature/fix] and spans these files:
    - Section Y: [file pair 1]
    - Section Z: [file pair 2]
    ...

    Read UPSTREAM_PORTING_GUIDE.md sections Y, Z, ... for detailed transformation rules and upstream deltas.

    Current State: The Phoenix LiveView dependency has been updated, causing pre-existing test failures.
    Run `mix test` first to see which tests are currently failing. ALL failures (pre-existing and new)
    MUST be fixed - they are NOT out of scope.

    For each file in this task, review its section in the guide for:
    - FILE-GLOBAL TRANSFORMATION RULES
    - UPSTREAM DELTA details

    This task has [N] upstream deltas across all affected files. You must address ALL of them.

    For each delta, either:
    - Port it to LVN (apply transformation rules from the guide)
    - Document why it's not applicable (e.g., CSS/JS per constraints, web-specific,
      already implemented differently in LVN, etc.)

    Requirements:
    - Address ALL upstream deltas for this TASK (across all affected files)
    - Use transformation rules from the guide
    - Follow the CONSTRAINTS in the guide (see top of UPSTREAM_PORTING_GUIDE.md)
    - Run tests and FIX ALL failures - both pre-existing (from dependency update) and new failures
    - Ensure no NEW test failures unrelated to this task
    - Clear all compilation errors and warnings
    - Do NOT make changes for files outside this task
    - **MANDATORY: COMMIT your changes** with a descriptive commit message when done
      * DO NOT report completion without committing first
      * Commit message should describe WHAT changed and WHY (from a normal dev perspective)
      * DO NOT reference migration guide, sections, deltas, or tasks in commit messages
      * Write as if explaining to someone without access to the porting guide
      * Good: "Add slot annotation support to rendering engine for better debugging"
      * Bad: "Port section 9, delta 3 - annotate_slot callback"
      * Good: "Fix upload timeout handling to prevent indefinite hangs"
      * Bad: "Complete Task 2 (upload deltas from sections 5-7)"

    **CRITICAL - TEST FAILURE HANDLING:**
    - Pre-existing test failures from the dependency update MUST be fixed (they're not out of scope)
    - New test failures from your changes MUST be fixed
    - Test failures are EXPECTED during porting - your job is to FIX them, not abort
    - Only stop if the APPROACH is wrong (wrong order, missing prereqs, need to rethink strategy)
    - After this step: ALL related tests should pass, NO new unrelated failures

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
    - Summary of what was ported for each delta (for internal tracking - OK to reference sections)
    - Any exclusions/non-applicable changes with justification
    - Test results: MUST show ALL tests passing (or explain which failures remain and why)
    - Confirmation that no new unrelated test failures were introduced
    - **MANDATORY: Git commit confirmation** - provide the commit hash and message
      * DO NOT report completion without committing first
      * Verify the commit message follows the guidelines (no section/delta/task references)

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
    - The Phoenix LiveView dependency has already been updated, causing pre-existing test failures
    - ALL test failures (pre-existing and new) MUST be fixed - they are NOT out of scope
    - Changes should prioritize fixing the pre-existing test failures first
    - Changes should be made in logical steps with git commits after each step
    - After each step: ALL related tests should pass, NO new unrelated test failures

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
