defmodule TrackUpstream.FileMatcher do
  @moduledoc """
  File matching logic using semantic similarity.
  """

  alias TrackUpstream.{Config, Git, OpenAI}

  @doc """
  Find the closest matching LVN file for a given PLV file.
  Returns {plv_file, best_match, similarity, verification} or nil.
  """
  def find_closest_match(plv_file, plv_dir, plv_rev, lvn_files, lvn_dir, lvn_rev) do
    case Git.get_file_content(plv_dir, plv_rev, plv_file) do
      {:ok, plv_content} when byte_size(plv_content) > 0 ->
        # Compare with all LVN files using embeddings
        {best_match, best_similarity, best_lvn_content} =
          lvn_files
          |> Enum.reduce({nil, 0.0, nil}, fn lvn_file, {best_file, best_sim, best_content} ->
            case Git.get_file_content(lvn_dir, lvn_rev, lvn_file) do
              {:ok, lvn_content} when byte_size(lvn_content) > 0 ->
                # Use embedding-based cosine similarity
                similarity = OpenAI.Embeddings.similarity(plv_content, lvn_content)

                if similarity > best_sim do
                  {lvn_file, similarity, lvn_content}
                else
                  {best_file, best_sim, best_content}
                end

              _ ->
                {best_file, best_sim, best_content}
            end
          end)

        if best_match do
          # For matches >70%, verify with LLM
          threshold = Config.analysis_config().similarity_threshold

          verification =
            if best_similarity > threshold do
              IO.write(".")
              OpenAI.Chat.verify_translation(plv_file, plv_content, best_match, best_lvn_content)
            else
              nil
            end

          {plv_file, best_match, best_similarity, verification}
        else
          nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Get all modules defined in lib files using LLM.
  """
  def get_modules_from_lib_files(dir, rev, lib_files) do
    concurrency = Config.analysis_config().concurrency

    lib_files
    |> Task.async_stream(
      fn lib_file ->
        case Git.get_file_content(dir, rev, lib_file) do
          {:ok, content} ->
            modules = OpenAI.Chat.extract_defined_modules(lib_file, content)
            IO.write(".")
            modules

          _ ->
            []
        end
      end,
      timeout: :infinity,
      max_concurrency: concurrency
    )
    |> Enum.map(fn {:ok, result} -> result end)
    |> List.flatten()
    |> MapSet.new()
  end
end
