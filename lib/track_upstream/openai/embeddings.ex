defmodule TrackUpstream.OpenAI.Embeddings do
  @moduledoc """
  OpenAI embedding operations for semantic similarity.

  Note: Uses direct Req calls for embeddings since LangChain Elixir doesn't
  currently provide embeddings support. Chat completions use LangChain.
  """

  alias TrackUpstream.{Cache, Config}

  @doc """
  Calculate embedding similarity between two pieces of content.
  Uses cosine similarity between OpenAI embeddings.
  """
  def similarity(content1, content2) do
    # Create cache key from both contents
    cache_key = :crypto.hash(:sha256, content1 <> content2) |> Base.encode16(case: :lower)

    Cache.get_or_compute(:similarity, cache_key, fn ->
      # Get embeddings (with caching)
      embedding1 = get_embedding(content1)
      embedding2 = get_embedding(content2)

      # Calculate cosine similarity
      cosine_similarity(embedding1, embedding2)
    end)
  end

  @doc """
  Get embedding for content (with caching).
  """
  def get_embedding(content) do
    # Create cache key from content hash
    cache_key = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)

    Cache.get_or_compute(:embeddings, cache_key, fn ->
      fetch_embedding_from_openai(content)
    end)
  end

  # Private functions

  defp fetch_embedding_from_openai(content) do
    api_key = System.get_env("OPENAI_API_KEY")
    unless api_key, do: raise "OPENAI_API_KEY environment variable not set"

    config = Config.openai_config()

    # Truncate if too long
    content =
      if String.length(content) > config.max_content_length do
        String.slice(content, 0, config.max_content_length)
      else
        content
      end

    # Direct API call using Req (LangChain doesn't support embeddings yet)
    response =
      Req.post!(
        "https://api.openai.com/v1/embeddings",
        json: %{
          model: config.embedding_model,
          input: content
        },
        headers: [{"Authorization", "Bearer #{api_key}"}],
        retry: :transient
      )

    case response.status do
      200 ->
        %{"data" => [%{"embedding" => embedding}]} = response.body
        embedding

      _ ->
        raise "OpenAI API error: #{inspect(response)}"
    end
  end

  defp cosine_similarity(vec1, vec2) do
    dot_product =
      Enum.zip(vec1, vec2)
      |> Enum.map(fn {a, b} -> a * b end)
      |> Enum.sum()

    magnitude1 = :math.sqrt(Enum.map(vec1, fn x -> x * x end) |> Enum.sum())
    magnitude2 = :math.sqrt(Enum.map(vec2, fn x -> x * x end) |> Enum.sum())

    if magnitude1 > 0 and magnitude2 > 0 do
      dot_product / (magnitude1 * magnitude2)
    else
      0.0
    end
  end
end
