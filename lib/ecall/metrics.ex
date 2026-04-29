defmodule Ecall.Metrics do
  use GenServer

  @table __MODULE__
  @events [
    :call_initiated_total,
    :call_reused_total,
    :call_accepted_total,
    :call_rejected_total,
    :call_busy_total,
    :call_ended_total,
    :call_missed_total,
    :signaling_errors_total,
    :message_created_total,
    :message_sync_total,
    :push_delivered_total,
    :push_failed_total,
    :push_invalid_token_total,
    :push_retry_delivered_total,
    :push_retry_failed_total,
    :websocket_auth_rejected_total,
    :channel_join_forbidden_total,
    :call_reconnecting_total,
    :call_reconnected_total,
    :call_admission_rejected_total,
    :call_rate_limited_total,
    :call_ringing_ack_total
  ]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])

    Enum.each(@events, fn event ->
      :ets.insert(@table, {event, 0})
    end)

    {:ok, %{}}
  end

  def inc(event) when event in @events do
    :ets.update_counter(@table, event, 1, {event, 0})
    :ok
  rescue
    ArgumentError -> :ok
  end

  def get(event) when event in @events do
    case :ets.lookup(@table, event) do
      [{^event, value}] -> value
      [] -> 0
    end
  rescue
    ArgumentError -> 0
  end

  def all do
    Map.new(@events, &{&1, get(&1)})
  end
end
