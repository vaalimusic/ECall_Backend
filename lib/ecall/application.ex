defmodule Ecall.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Ecall.Repo,
      cluster_child(),
      Ecall.Metrics,
      {Phoenix.PubSub, name: Ecall.PubSub},
      EcallWeb.Presence,
      Ecall.Calls.Registry,
      timeout_worker_child(),
      participant_sweeper_child(),
      push_retry_worker_child(),
      goth_child(),
      EcallWeb.Telemetry,
      {Finch, name: Ecall.Finch},
      EcallWeb.Endpoint
    ]
    |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: Ecall.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    EcallWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp timeout_worker_child do
    opts = Application.get_env(:ecall, Ecall.Calls.TimeoutWorker, [])

    if Keyword.get(opts, :enabled, true) do
      Ecall.Calls.TimeoutWorker
    end
  end

  defp cluster_child do
    topologies = Application.get_env(:libcluster, :topologies, [])

    if topologies != [] do
      {Cluster.Supervisor, [topologies, [name: Ecall.ClusterSupervisor]]}
    end
  end

  defp push_retry_worker_child do
    opts = Application.get_env(:ecall, Ecall.Push.RetryWorker, [])

    if Keyword.get(opts, :enabled, true) do
      Ecall.Push.RetryWorker
    end
  end

  defp goth_child do
    case Application.get_env(:ecall, Ecall.Goth, [])[:source] do
      nil -> nil
      source -> {Goth, name: Ecall.Goth, source: source}
    end
  end

  defp participant_sweeper_child do
    opts = Application.get_env(:ecall, Ecall.Calls.ParticipantSweeper, [])

    if Keyword.get(opts, :enabled, true) do
      {Ecall.Calls.ParticipantSweeper, opts}
    end
  end
end
