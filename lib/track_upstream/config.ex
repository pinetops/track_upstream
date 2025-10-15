defmodule TrackUpstream.Config do
  @moduledoc """
  Configuration and constants for upstream change tracking.

  Configuration is loaded from .track_upstream_config.md in the downstream project directory.
  If the file doesn't exist, default instructions are provided explaining the required format.
  """

  @cache_dirs %{
    embeddings: ".track_changes_cache/embeddings",
    similarity: ".track_changes_cache/similarity",
    verification: ".track_changes_cache/verification",
    git_content: ".track_changes_cache/git_content",
    modules: ".track_changes_cache/modules"
  }

  @openai_config %{
    embedding_model: "text-embedding-3-small",
    chat_model: "gpt-4o-mini",
    analysis_model: "gpt-4o",
    max_content_length: 20_000,
    timeout: 120_000
  }

  @analysis_config %{
    similarity_threshold: 0.70,
    concurrency: System.schedulers_online() * 2
  }

  def cache_dirs, do: @cache_dirs
  def openai_config, do: @openai_config
  def analysis_config, do: @analysis_config

  @doc "Ensure all cache directories exist"
  def ensure_cache_dirs! do
    Enum.each(@cache_dirs, fn {_name, dir} ->
      File.mkdir_p!(dir)
    end)
  end

  @doc "Validate OpenAI API configuration is ready"
  def validate! do
    api_key = System.get_env("OPENAI_API_KEY")
    unless api_key, do: raise "OPENAI_API_KEY environment variable not set"
    ensure_cache_dirs!()
    :ok
  end

  @doc "Get porting constraints from config file or use default message"
  def porting_constraints do
    config_file = ".track_upstream_config.md"

    if File.exists?(config_file) do
      content = File.read!(config_file)
      # Extract the porting constraints section
      case Regex.run(~r/## Porting Constraints\n\n(.+)/s, content) do
        [_, constraints] ->
          # Take until next ## header or end
          constraints
          |> String.split(~r/^##\s/m)
          |> hd()
          |> String.trim()

        _ ->
          default_porting_constraints()
      end
    else
      default_porting_constraints()
    end
  end

  defp default_porting_constraints do
    """
    IMPORTANT: No .track_upstream_config.md file found in current directory.

    Please create a .track_upstream_config.md file with the following format:

    # Track Upstream Configuration

    ## Upstream Project

    **Name:** [Upstream Project Name]
    **Abbreviation:** [ABBREV]

    ## Downstream Project

    **Name:** [Your Project Name]
    **Abbreviation:** [ABBREV]
    **Repository Path:** .

    ## Porting Constraints

    IMPORTANT CONSTRAINTS when porting from upstream to downstream:

    1. **Technology-Specific Adaptations:**
       - Describe any platform differences (e.g., HTML vs native platforms)
       - Explain how upstream concepts map to downstream

    2. **Features that should NOT be ported:**
       - List upstream features that don't apply to downstream
       - Explain why (e.g., web-specific, platform-specific, etc.)

    3. **Naming Conventions:**
       - Module namespace transformations (e.g., Upstream.Module → Downstream.Module)
       - File path conventions
       - Other systematic naming changes

    See https://github.com/liveview-native/live_view_native for a complete example.
    """
  end
end
