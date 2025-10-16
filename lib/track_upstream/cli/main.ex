defmodule TrackUpstream.CLI.Main do
  @moduledoc """
  Main entry point for the track_upstream escript.
  """

  def main(args) do
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

    # Start required applications
    Application.ensure_all_started(:crypto)
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:jason)
    Application.ensure_all_started(:telemetry)
    Application.ensure_all_started(:finch)

    # Start Finch pool if not already running
    case Process.whereis(Req.Finch) do
      nil -> Finch.start_link(name: Req.Finch)
      pid -> {:ok, pid}
    end

    # Run the CLI
    TrackUpstream.CLI.run(upstream_start_rev, upstream_end_rev, downstream_rev, final_opts)
  end

  defp print_usage do
    IO.puts("""
    Usage: track_upstream <upstream_start_rev> <upstream_end_rev> <downstream_rev> --upstream-dir <path>

    Arguments:
      upstream_start_rev     - Upstream starting revision (e.g., v2.0.0, commit hash, branch)
      upstream_end_rev       - Upstream ending revision (e.g., main, v2.1.0, commit hash)
      downstream_rev         - Downstream revision to compare (e.g., main, commit hash)
      --upstream-dir <path>  - Path to upstream repository (required)

    Examples:
      track_upstream v2.0.0 main main --upstream-dir ../upstream-repo
      track_upstream abc123 def456 main --upstream-dir /path/to/upstream

    Configuration:
      Create .track_upstream_config.md in your project directory.
      See https://github.com/pinetops/track_upstream for configuration format.
    """)
  end
end
