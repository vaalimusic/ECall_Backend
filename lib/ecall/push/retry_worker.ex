defmodule Ecall.Push.RetryWorker do
  use GenServer

  require Logger

  @default_interval_ms 10_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_tick()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick, state) do
    case Ecall.Push.process_due_jobs() do
      count when count > 0 -> Logger.info("processed push retry jobs count=#{count}")
      _count -> :ok
    end

    schedule_tick()
    {:noreply, state}
  rescue
    error ->
      Logger.error("push retry worker failed: #{Exception.message(error)}")
      schedule_tick()
      {:noreply, state}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, interval_ms())
  end

  defp interval_ms do
    :ecall
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:interval_ms, @default_interval_ms)
  end
end
