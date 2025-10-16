defmodule TrackUpstream.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: Req.Finch}
    ]

    opts = [strategy: :one_for_one, name: TrackUpstream.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
