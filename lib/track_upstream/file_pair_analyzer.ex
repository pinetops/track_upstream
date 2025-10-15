defmodule TrackUpstream.FilePairAnalyzer do
  @moduledoc """
  Generate diffs for a file pair to show upstream changes and baseline transformations.
  """

  alias TrackUpstream.Git

  @doc """
  Generate formatted diff output for a file pair.
  Returns a string containing three diffs:
  1. PLV start → PLV end (upstream changes)
  2. PLV start → LVN start (baseline transformation)
  3. LVN start → workdir (work in progress)
  """
  def analyze_file_pair(plv_start_rev, plv_end_rev, lvn_start_rev, plv_file, lvn_file) do
    plv_dir = "../phoenix_live_view"
    lvn_dir = "."

    header = """
    #{"=" |> String.duplicate(80)}
    FILE PAIR ANALYSIS
    #{"=" |> String.duplicate(80)}
    PLV: #{plv_file}
    LVN: #{lvn_file}

    """

    diff1 = """
    ### DIFF 1: Phoenix LiveView #{plv_start_rev}..#{plv_end_rev} ###
    #{generate_repo_diff(plv_dir, plv_start_rev, plv_end_rev, plv_file)}

    """

    diff2 = """
    ### DIFF 2: PLV #{plv_start_rev} -> LVN #{lvn_start_rev} ###
    #{generate_cross_repo_diff(plv_dir, plv_start_rev, plv_file, lvn_dir, lvn_start_rev, lvn_file)}

    """

    diff3 = """
    ### DIFF 3: LVN #{lvn_start_rev} -> workdir ###
    #{generate_workdir_diff(lvn_dir, lvn_start_rev, lvn_file)}

    """

    footer = "#{String.duplicate("=", 80)}\n"

    header <> diff1 <> diff2 <> diff3 <> footer
  end

  # Private functions

  defp generate_repo_diff(dir, start_rev, end_rev, file) do
    case System.cmd("git", ["-C", dir, "diff", "#{start_rev}..#{end_rev}", "--", file],
           stderr_to_stdout: true
         ) do
      {output, 0} when byte_size(output) > 0 ->
        output

      {_, 0} ->
        "(no changes)"

      {error, _} ->
        "Error: #{error}"
    end
  end

  defp generate_cross_repo_diff(plv_dir, plv_rev, plv_file, lvn_dir, lvn_rev, lvn_file) do
    with {:ok, plv_content} <- Git.get_file_content(plv_dir, plv_rev, plv_file),
         {:ok, lvn_content} <- Git.get_file_content(lvn_dir, lvn_rev, lvn_file) do
      # Create temp files
      plv_temp = System.tmp_dir!() |> Path.join("plv_#{Path.basename(plv_file)}")
      lvn_temp = System.tmp_dir!() |> Path.join("lvn_#{Path.basename(lvn_file)}")

      File.write!(plv_temp, plv_content)
      File.write!(lvn_temp, lvn_content)

      # Generate diff
      result =
        case System.cmd("diff", ["-u", plv_temp, lvn_temp], stderr_to_stdout: true) do
          {output, exit_code} when exit_code in [0, 1] ->
            # Replace temp file paths with meaningful names
            output =
              output
              |> String.replace(plv_temp, "PLV:#{plv_file}")
              |> String.replace(lvn_temp, "LVN:#{lvn_file}")

            if byte_size(output) > 0 do
              output
            else
              "(identical)"
            end

          {error, _} ->
            "Error: #{error}"
        end

      # Clean up temp files
      File.rm(plv_temp)
      File.rm(lvn_temp)

      result
    else
      _ -> "Error: Could not read file contents"
    end
  end

  defp generate_workdir_diff(dir, rev, file) do
    case System.cmd("git", ["-C", dir, "diff", rev, "--", file], stderr_to_stdout: true) do
      {output, 0} when byte_size(output) > 0 ->
        output

      {_, 0} ->
        "(no changes)"

      {error, _} ->
        "Error: #{error}"
    end
  end
end
