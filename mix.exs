defmodule TrackUpstream.MixProject do
  use Mix.Project

  def project do
    [
      app: :track_upstream,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp escript do
    [
      main_module: TrackUpstream.Main,
      name: "track_upstream"
    ]
  end

  defp deps do
    [
      {:req, "~> 0.4.0"},
      {:jason, "~> 1.4"},
      {:finch, "~> 0.16"}
    ]
  end
end
