defmodule TrackUpstream.Git do
  @moduledoc """
  Git operations for reading file lists and content from repositories.
  """

  alias TrackUpstream.Config

  @doc """
  Get list of Elixir files from a git repository at a specific revision.
  Filters to only include lib/ and test/ directories, excluding test/e2e/.
  """
  def get_elixir_files(dir, rev) do
    {output, 0} = System.cmd("git", ["-C", dir, "ls-tree", "-r", "--name-only", rev])

    output
    |> String.split("\n", trim: true)
    |> Enum.filter(&String.match?(&1, ~r/\.(ex|exs)$/))
    |> Enum.filter(&String.match?(&1, ~r/^(lib|test)\//))
    |> Enum.reject(&String.starts_with?(&1, "test/e2e/"))
  end

  @doc """
  Get file content from a git repository at a specific revision.
  Results are cached to avoid redundant git operations.
  """
  def get_file_content(dir, rev, file) do
    cache_dir = Config.cache_dirs().git_content
    File.mkdir_p!(cache_dir)

    # Create cache key from dir, rev, and file
    cache_key = :crypto.hash(:sha256, "#{dir}:#{rev}:#{file}") |> Base.encode16(case: :lower)
    cache_file = Path.join(cache_dir, "#{cache_key}.txt")

    # Check cache first
    if File.exists?(cache_file) do
      content = File.read!(cache_file)
      {:ok, content}
    else
      case System.cmd("git", ["-C", dir, "show", "#{rev}:#{file}"], stderr_to_stdout: true) do
        {content, 0} ->
          File.write!(cache_file, content)
          {:ok, content}

        _ ->
          :error
      end
    end
  end

  @doc """
  Check if a file has changes between two revisions in a git repository.
  """
  def has_changes?(dir, start_rev, end_rev, file) do
    case System.cmd("git", ["-C", dir, "diff", "#{start_rev}..#{end_rev}", "--", file],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        # If diff output is not empty, there are changes
        String.trim(output) != ""

      _ ->
        # If git diff fails, assume no changes
        false
    end
  end
end
