defmodule Ecall.Calls.Registry do
  use GenServer

  require Logger

  defstruct calls: %{}

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)

  def start_call(call_id, caller_id, callee_id, timeout_ms) do
    GenServer.call(__MODULE__, {:start_call, call_id, caller_id, callee_id, timeout_ms})
  end

  def active_count do
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, :count), else: 0
  end
  def join(call_id, user_id), do: GenServer.cast(__MODULE__, {:join, call_id, user_id})
  def leave(call_id, user_id), do: GenServer.cast(__MODULE__, {:leave, call_id, user_id})
  def update_status(call_id, status), do: GenServer.cast(__MODULE__, {:status, call_id, status})

  def emit_metrics do
    :telemetry.execute([:ecall, :calls, :active], %{count: active_count()}, %{})
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:start_call, call_id, caller_id, callee_id, timeout_ms}, _from, state) do
    timer = Process.send_after(self(), {:timeout, call_id}, timeout_ms)

    call = %{
      caller_id: caller_id,
      callee_id: callee_id,
      status: :ringing,
      participants: MapSet.new([caller_id]),
      timer: timer
    }

    {:reply, :ok, put_in(state.calls[call_id], call)}
  end

  def handle_call(:count, _from, state), do: {:reply, map_size(state.calls), state}

  @impl true
  def handle_cast({:join, call_id, user_id}, state) do
    {:noreply, update_call_participants(state, call_id, &MapSet.put(&1, user_id))}
  end

  def handle_cast({:leave, call_id, user_id}, state) do
    {:noreply, update_call_participants(state, call_id, &MapSet.delete(&1, user_id))}
  end

  def handle_cast({:status, call_id, status}, state) do
    state =
      update_in(state.calls[call_id], fn
        nil -> nil
        call -> %{call | status: status}
      end)

    if status in [:accepted, :rejected, :busy, :ended, :timeout, :missed], do: cancel_timer(state.calls[call_id])

    state =
      if status in [:rejected, :busy, :ended, :timeout, :missed] do
        update_in(state.calls, &Map.delete(&1, call_id))
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:timeout, call_id}, state) do
    Task.start(fn ->
      Ecall.Calls.mark_timeout(call_id)
      EcallWeb.Endpoint.broadcast("call:#{call_id}", "call:timeout", %{"call_id" => call_id})
    end)

    {:noreply, update_in(state.calls, &Map.delete(&1, call_id))}
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(%{timer: timer}), do: Process.cancel_timer(timer)

  defp update_call_participants(state, call_id, fun) do
    update_in(state.calls[call_id], fn
      nil -> nil
      call -> %{call | participants: fun.(call.participants)}
    end)
  end
end
