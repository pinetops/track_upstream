defmodule TrackUpstream.MixProject do
  use Mix.Project

  def project do
    [
      app: :track_upstream,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:langchain, "~> 0.3.0"},
      {:jason, "~> 1.4"}
    ]
  end
end
