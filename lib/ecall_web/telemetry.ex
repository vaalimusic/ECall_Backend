defmodule EcallWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      counter("ecall.signaling.event.count", tags: [:event]),
      summary("ecall.signaling.event.latency", measurement: :latency, unit: {:native, :millisecond}, tags: [:event]),
      last_value("ecall.calls.active.count"),
      summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond})
    ]
  end

  defp periodic_measurements do
    [
      {Ecall.Calls.Registry, :emit_metrics, []}
    ]
  end
end
