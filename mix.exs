defmodule TrackUpstream.MixProject do
  use Mix.Project

  def project do
    [
      app: :track_upstream,
      version: "0.1.0",
      elixir: "~> 1.15",
      description: description(),
      package: package(),
      deps: deps(),
      source_url: "https://github.com/pinetops/track_upstream",
      homepage_url: "https://github.com/pinetops/track_upstream",
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :ssl, :inets]
    ]
  end

  defp escript do
    [
      main_module: TrackUpstream.CLI.Main,
      path: "track_upstream"
    ]
  end

  defp description do
    """
    A command-line tool for tracking and analyzing upstream changes between derivative projects.
    Uses OpenAI embeddings for semantic code matching to identify analogous files and generate
    porting guides for maintaining downstream projects.
    """
  end

  defp package do
    [
      name: "track_upstream",
      files: ~w(lib mix.exs README.md LICENSE .formatter.exs),
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/pinetops/track_upstream"
      }
    ]
  end

  defp deps do
    [
      {:langchain, "~> 0.3.0"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5.2"}
    ]
  end
end
