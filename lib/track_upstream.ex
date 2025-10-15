defmodule TrackUpstream do
  @moduledoc """
  Upstream changes tracker for matching files between derivative project codebases.

  Uses OpenAI embeddings with cosine similarity for semantic code matching.
  All embeddings and analysis results are cached locally to avoid redundant API calls.
  """
end
