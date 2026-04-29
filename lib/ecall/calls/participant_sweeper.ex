defmodule Ecall.Calls.ParticipantSweeper do
  use GenServer

  require Logger

  @default_interval_ms 15_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval_ms = Keyword.get(opts, :interval_ms, configured_interval_ms())
    schedule(interval_ms)
    {:ok, %{interval_ms: interval_ms}}
  end

  @impl true
  def handle_info(:sweep, state) do
    count = Ecall.Calls.mark_stale_participants_left()

    if count > 0 do
      Logger.info("marked stale call participants left count=#{count}")
    end

    schedule(state.interval_ms)
    {:noreply, state}
  end

  defp schedule(interval_ms), do: Process.send_after(self(), :sweep, interval_ms)

  defp configured_interval_ms do
    :ecall
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:interval_ms, @default_interval_ms)
  end
end
