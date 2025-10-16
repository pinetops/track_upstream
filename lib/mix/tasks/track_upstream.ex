defmodule Mix.Tasks.TrackUpstream do
  @shortdoc "Track upstream changes between derivative projects"

  @moduledoc """
  Track and analyze upstream changes that need to be ported to a derivative project.

  Uses OpenAI embeddings with cosine similarity for semantic code matching.
  All embeddings and analysis results are cached locally to avoid redundant API calls.

  ## Installation

  ### Global installation (recommended)

  Install from GitHub:

      mix archive.install github pinetops/track_upstream

  Or build and install locally:

      git clone https://github.com/pinetops/track_upstream.git
      cd track_upstream
      mix do deps.get, archive.build, archive.install

  Then use from anywhere:

      mix track_upstream <args>

  To update:

      mix archive.install github pinetops/track_upstream --force

  To uninstall:

      mix archive.uninstall track_upstream

  ### Local usage (within a project)

  Add to dependencies in mix.exs:

      {:track_upstream, github: "pinetops/track_upstream"}

  Then:

      mix deps.get
      mix track_upstream <args>

  ## Usage

      mix track_upstream <upstream_start_rev> <upstream_end_rev> <downstream_rev> --upstream-dir <path>

  ## Arguments

    * `upstream_start_rev` - Upstream starting revision (e.g., v2.0.0, commit hash, branch)
    * `upstream_end_rev` - Upstream ending revision (e.g., main, v2.1.0, commit hash)
    * `downstream_rev` - Downstream revision to compare (e.g., main, commit hash)
    * `--upstream-dir <path>` - Path to upstream repository (required)

  ## Examples

      mix track_upstream v2.0.0 main main --upstream-dir ../upstream-repo
      mix track_upstream abc123 def456 main --upstream-dir /absolute/path/to/upstream

  ## Configuration

  Create a `.track_upstream_config.md` file in your downstream project directory.
  This file should contain:
  - Upstream and downstream project names and abbreviations
  - Porting constraints specific to your project

  See https://github.com/pinetops/track_upstream for an example configuration file.

  ## Requirements

    * `OPENAI_API_KEY` environment variable must be set
    * Run from downstream project directory

  ## Output

    * Matched file pairs (existing upstream/downstream files)
    * Newly added upstream files categorized by relevance
    * Summary statistics
    * Individual file pair analyses in `translation_analyses/` directory
    * Global porting guide in `UPSTREAM_PORTING_GUIDE.md`
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    # Parse arguments
    {opts, remaining, _invalid} = OptionParser.parse(args,
      switches: [upstream_dir: :string],
      aliases: []
    )

    {upstream_start_rev, upstream_end_rev, downstream_rev} =
      case remaining do
        [upstream_start_rev, upstream_end_rev, downstream_rev] ->
          {upstream_start_rev, upstream_end_rev, downstream_rev}

        _ ->
          print_usage()
          System.halt(1)
      end

    upstream_dir = opts[:upstream_dir]

    unless upstream_dir do
      IO.puts("\nError: --upstream-dir is required\n")
      print_usage()
      System.halt(1)
    end

    final_opts = [upstream_dir: upstream_dir, analyze: true]

    # Ensure the application is started (which starts Finch supervisor)
    Application.ensure_all_started(:track_upstream)

    # Run the CLI
    TrackUpstream.CLI.run(upstream_start_rev, upstream_end_rev, downstream_rev, final_opts)
  end

  defp print_usage do
    IO.puts("""
    Usage: mix track_upstream <upstream_start_rev> <upstream_end_rev> <downstream_rev> --upstream-dir <path>

    Arguments:
      upstream_start_rev     - Upstream starting revision (e.g., v2.0.0, commit hash, branch)
      upstream_end_rev       - Upstream ending revision (e.g., main, v2.1.0, commit hash)
      downstream_rev         - Downstream revision to compare (e.g., main, commit hash)
      --upstream-dir <path>  - Path to upstream repository (required)

    Examples:
      mix track_upstream v2.0.0 main main --upstream-dir ../upstream-repo
      mix track_upstream abc123 def456 main --upstream-dir /path/to/upstream

    Configuration:
      Create .track_upstream_config.md in your project directory.
      See https://github.com/pinetops/track_upstream for configuration format.

    For more information, run: mix help track_upstream
    """)
  end
end
