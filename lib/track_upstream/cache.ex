defmodule TrackUpstream.Cache do
  @moduledoc """
  Generic caching utilities for JSON data.
  """

  alias TrackUpstream.Config

  @doc """
  Get cached value or compute it if not in cache.
  Handles corrupted/empty cache files by treating them as cache misses.
  """
  def get_or_compute(cache_type, key, compute_fn) do
    cache_dir = Config.cache_dirs()[cache_type]
    File.mkdir_p!(cache_dir)

    cache_file = Path.join(cache_dir, "#{key}.json")

    if File.exists?(cache_file) do
      case File.read(cache_file) do
        {:ok, ""} ->
          # Empty file, treat as cache miss
          compute_and_cache(cache_file, compute_fn)

        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, result} ->
              result

            {:error, _} ->
              # Corrupted cache, recompute
              compute_and_cache(cache_file, compute_fn)
          end

        {:error, _} ->
          # Can't read file, recompute
          compute_and_cache(cache_file, compute_fn)
      end
    else
      compute_and_cache(cache_file, compute_fn)
    end
  end

  defp compute_and_cache(cache_file, compute_fn) do
    result = compute_fn.()
    File.write!(cache_file, Jason.encode!(result))
    result
  end

  @doc """
  Get cached text content or compute it if not in cache.
  """
  def get_or_compute_text(cache_type, key, compute_fn) do
    cache_dir = Config.cache_dirs()[cache_type]
    File.mkdir_p!(cache_dir)

    cache_file = Path.join(cache_dir, "#{key}.txt")

    if File.exists?(cache_file) do
      File.read!(cache_file)
    else
      result = compute_fn.()
      File.write!(cache_file, result)
      result
    end
  end
end
