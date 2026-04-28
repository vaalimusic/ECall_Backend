defmodule Ecall.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EcallWeb.Telemetry,
      Ecall.Repo,
      {Phoenix.PubSub, name: Ecall.PubSub},
      EcallWeb.Presence,
      Ecall.Calls.Registry,
      {Finch, name: Ecall.Finch},
      EcallWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Ecall.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    EcallWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
