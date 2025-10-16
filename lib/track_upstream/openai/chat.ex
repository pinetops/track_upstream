defmodule TrackUpstream.OpenAI.Chat do
  @moduledoc """
  OpenAI chat operations for LLM-based verification and analysis.
  """

  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Message
  alias TrackUpstream.{Cache, Config}

  @doc """
  Verify if one file is a translation/port of another using LLM.
  """
  def verify_translation(plv_file, plv_content, lvn_file, lvn_content) do
    # Create cache key from both file contents
    cache_key =
      :crypto.hash(:sha256, plv_content <> lvn_content) |> Base.encode16(case: :lower)

    Cache.get_or_compute(:verification, cache_key, fn ->
      ask_llm_verification(plv_file, plv_content, lvn_file, lvn_content)
    end)
  end

  @doc """
  Extract module names defined in a lib file using LLM.
  """
  def extract_defined_modules(file_path, content) do
    cache_key = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)

    Cache.get_or_compute(:modules, "defined_#{cache_key}", fn ->
      query_modules(file_path, content, :defined)
    end)
  end

  @doc """
  Get modules tested in a test file using LLM.
  """
  def get_tested_modules(file_path, content) do
    cache_key = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)

    Cache.get_or_compute(:modules, "tested_#{cache_key}", fn ->
      query_modules(file_path, content, :tested)
    end)
  end

  @doc """
  Generate a description of a file for LLM consumption.
  """
  def generate_file_description(file_path, content) do
    api_key = System.get_env("OPENAI_API_KEY")
    unless api_key, do: raise "OPENAI_API_KEY not set"

    config = Config.openai_config()

    # Truncate if needed
    truncated_content =
      if String.length(content) > config.max_content_length do
        String.slice(content, 0, config.max_content_length) <> "\n... [truncated]"
      else
        content
      end

    prompt = """
    Analyze this newly added Phoenix LiveView file and provide a concise description that helps determine when this file is relevant for porting to LiveView Native.

    **File:** #{file_path}

    **Content:**
    ```elixir
    #{truncated_content}
    ```

    **Provide:**
    1. **Purpose:** What does this file do? (1-2 sentences)
    2. **Key exports:** Main functions, modules, or macros defined
    3. **Dependencies:** Notable dependencies or integrations with other LiveView components
    4. **Relevance for LVN:** When would this be needed in LiveView Native? (e.g., "only if implementing X feature", "core testing infrastructure", "web-specific, likely not needed")

    Keep the description concise and factual. Format as markdown.
    """

    case call_llm(config.chat_model, prompt, api_key) do
      {:ok, response} -> response
      {:error, _} -> "_Could not generate description (API error)_"
    end
  end

  @doc """
  Call OpenAI to perform analysis using the file-pair-analyzer agent.
  """
  def call_analysis_agent(prompt) do
    api_key = System.get_env("OPENAI_API_KEY")
    unless api_key, do: raise "OPENAI_API_KEY not set"

    config = Config.openai_config()

    # Read the file-pair-analyzer agent instructions
    agent_instructions = """
    TASK: Please upgrade the current version of LiveView Native to incorporate recent changes to Phoenix LiveView, of which it is a derivative.

    #{Config.porting_constraints()}

    CONTEXT:
    - BASELINE TRANSFORMATION: PLV start → LVN start shows how the original code was adapted
    - UPSTREAM DELTA: PLV start → PLV end shows what changed upstream that needs porting
    - YOUR JOB: Document the baseline transformation to guide applying the upstream delta

    Your task:
    1. Analyze DIFF 2 (PLV start → LVN start): Identify FILE-GLOBAL transformation rules
    2. Document these rules - they show HOW to adapt PLV code to LVN
    3. Analyze DIFF 1 (PLV start → PLV end): Show upstream changes in LLM-friendly format
    4. DO NOT LOSE INFORMATION - all changes must be accounted for

    Output format:

    ## FILE-GLOBAL TRANSFORMATION RULES (PLV start → LVN start)

    These rules describe how this file was adapted from PLV to LVN. Use these patterns when porting upstream changes.

    For each rule:
    - Rule name and pattern (e.g., "Module namespace: Phoenix.LiveView.X → LiveViewNative.X")
    - Number of applications
    - 1-2 concrete examples showing the transformation

    ## BASELINE TRANSFORMATION DETAILS (PLV start → LVN start)

    ### Mechanical Changes
    For each location where rules apply:
    - Location (function names or line ranges)
    - Which rules apply
    - Count

    ### Unique Semantic Changes
    For changes NOT covered by rules:
    - Description
    - Location
    - Before (PLV start) / After (LVN start) code
    - Why this adaptation was needed

    ## UPSTREAM DELTA (PLV start → PLV end)

    **These are the changes that need to be ported to LVN.**

    Format in an LLM-friendly way:
    - If no changes: state "No upstream changes"
    - If changes exist: show each change as:
      * Location (function/line)
      * What changed (before → after)
      * Type of change (new feature, bug fix, refactor, etc.)

    ## SUMMARY

    - Baseline transformation rules: [count]
    - Upstream changes to port: [count]
    - Key observations: [factual observations about applying transformation rules to the upstream changes]
    """

    case call_llm_with_system(config.analysis_model, agent_instructions, prompt, api_key,
           timeout: config.timeout
         ) do
      {:ok, response} -> response
      {:error, reason} -> "Error: OpenAI API call failed - #{inspect(reason)}"
    end
  end

  # Private functions

  defp ask_llm_verification(plv_file, plv_content, lvn_file, lvn_content) do
    api_key = System.get_env("OPENAI_API_KEY")
    unless api_key, do: raise "OPENAI_API_KEY environment variable not set"

    config = Config.openai_config()

    # Truncate if needed
    plv_content =
      if String.length(plv_content) > config.max_content_length do
        String.slice(plv_content, 0, config.max_content_length) <> "\n... [truncated]"
      else
        plv_content
      end

    lvn_content =
      if String.length(lvn_content) > config.max_content_length do
        String.slice(lvn_content, 0, config.max_content_length) <> "\n... [truncated]"
      else
        lvn_content
      end

    # Determine file types more precisely
    get_file_type = fn file ->
      cond do
        String.starts_with?(file, "lib/") -> :lib
        String.ends_with?(file, "_test.exs") -> :test
        String.starts_with?(file, "test/support/") -> :support
        String.starts_with?(file, "test/") -> :support
        true -> :unknown
      end
    end

    plv_type = get_file_type.(plv_file)
    lvn_type = get_file_type.(lvn_file)

    # If file types don't match, it's not a translation
    if plv_type != lvn_type do
      %{
        "is_translation" => false,
        "confidence" => "high",
        "reason" => "File types don't match: PLV is #{plv_type}, LVN is #{lvn_type}"
      }
    else
      prompt = """
      You are analyzing two Elixir source files to determine if the LiveView Native file was created by copying and adapting the Phoenix LiveView file.

      Context: LiveView Native was built by copying Phoenix LiveView files and modifying them to support native platforms. A "translation" means the LVN file was literally created from the PLV file as its source, with systematic changes like Phoenix.LiveView → LiveViewNative.

      Phoenix LiveView file:
      ```elixir
      #{plv_content}
      ```

      LiveView Native file:
      ```elixir
      #{lvn_content}
      ```

      To determine if this is a translation, answer these questions:

      1. What is the PRIMARY PURPOSE of the PLV file? (e.g., "tests routing behavior", "implements server channel", "defines component DSL")
      2. What is the PRIMARY PURPOSE of the LVN file?
      3. Are these purposes IDENTICAL? (not just similar domain, but the EXACT SAME thing)

      A TRUE translation means:
      - Both files serve the EXACT SAME PRIMARY PURPOSE
      - The overall architecture and flow are nearly IDENTICAL
      - The function signatures and control flow match closely
      - Only implementation DETAILS differ (e.g., HTML vs native, Phoenix.LiveView → LiveViewNative)
      - It's the SAME BLUEPRINT with platform-specific adaptations

      NOT a translation (even if high similarity):
      - Different primary purposes (e.g., routing tests vs integration tests, server vs client)
      - Similar domain but different features (e.g., both test LiveView but test different aspects)
      - Both use similar patterns but for different goals

      Answer with a JSON object:
      {
        "is_translation": true/false,
        "confidence": "high"/"medium"/"low",
        "reason": "brief explanation mentioning what each file does"
      }
      """

      case call_llm_json(config.chat_model, prompt, api_key) do
        {:ok, json} -> json
        {:error, _} -> %{"is_translation" => false, "confidence" => "low", "reason" => "API error"}
      end
    end
  end

  defp query_modules(file_path, content, mode) do
    api_key = System.get_env("OPENAI_API_KEY")
    unless api_key, do: raise "OPENAI_API_KEY not set"

    config = Config.openai_config()

    truncated_content =
      if String.length(content) > config.max_content_length do
        String.slice(content, 0, config.max_content_length) <> "\n... [truncated]"
      else
        content
      end

    prompt =
      case mode do
        :defined ->
          """
          List all Elixir module names defined in this file (#{file_path}).
          Only return module names that are defined with 'defmodule'.

          ```elixir
          #{truncated_content}
          ```

          Return a JSON array of module names (as strings):
          ["ModuleName1", "ModuleName2"]
          """

        :tested ->
          """
          List all Elixir module names that are being tested in this test file (#{file_path}).
          Look for modules that are imported, aliased, or directly referenced in tests.

          ```elixir
          #{truncated_content}
          ```

          Return a JSON array of module names (as strings):
          ["ModuleName1", "ModuleName2"]
          """
      end

    case call_llm_json(config.chat_model, prompt, api_key) do
      {:ok, decoded} ->
        # Handle both {"modules": [...]} and direct array
        case decoded do
          %{"modules" => modules} when is_list(modules) -> modules
          modules when is_list(modules) -> modules
          _ -> []
        end

      {:error, _} ->
        []
    end
  end

  # Helper functions for LangChain API calls

  defp call_llm(model, prompt, api_key, opts \\ []) do
    {:ok, chat} =
      ChatOpenAI.new(%{
        model: model,
        temperature: 0,
        api_key: api_key
      })

    message = Message.new_user!(prompt)

    case ChatOpenAI.call(chat, [message], opts) do
      {:ok, [%Message{role: :assistant, content: content} | _]} -> {:ok, content}
      {:error, reason} -> {:error, reason}
    end
  end

  defp call_llm_with_system(model, system_prompt, user_prompt, api_key, opts) do
    # Extract timeout from opts if present
    timeout = Keyword.get(opts, :timeout)

    chat_config = %{
      model: model,
      temperature: 0,
      api_key: api_key
    }

    # Add timeout to chat config if provided
    chat_config = if timeout, do: Map.put(chat_config, :timeout, timeout), else: chat_config

    {:ok, chat} = ChatOpenAI.new(chat_config)

    messages = [
      Message.new_system!(system_prompt),
      Message.new_user!(user_prompt)
    ]

    # Don't pass opts to call - LangChain doesn't handle them as request options
    case ChatOpenAI.call(chat, messages) do
      {:ok, [%Message{role: :assistant, content: content} | _]} -> {:ok, content}
      {:error, reason} -> {:error, reason}
    end
  end

  defp call_llm_json(model, prompt, api_key) do
    {:ok, chat} =
      ChatOpenAI.new(%{
        model: model,
        temperature: 0,
        response_format: %{type: "json_object"},
        api_key: api_key
      })

    message = Message.new_user!(prompt)

    case ChatOpenAI.call(chat, [message]) do
      {:ok, [%Message{role: :assistant, content: content} | _]} ->
        case Jason.decode(content) do
          {:ok, json} -> {:ok, json}
          error -> error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
