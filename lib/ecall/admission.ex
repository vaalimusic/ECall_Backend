defmodule Ecall.Admission do
  @moduledoc false

  import Ecto.Query

  alias Ecall.Calls.Call
  alias Ecall.Repo

  @active_statuses [:initiated, :ringing, :accepted]

  def admit_call_start(caller_id) do
    with :ok <- admit_caller_rate(caller_id),
         :ok <- admit_vm(),
         :ok <- admit_active_calls() do
      :ok
    end
  end

  def snapshot do
    :ecall_admission.snapshot()
  end

  defp admit_vm do
    opts = Application.get_env(:ecall, __MODULE__, [])

    max_processes = Keyword.get(opts, :max_processes)
    max_run_queue = Keyword.get(opts, :max_run_queue)
    max_memory_bytes = Keyword.get(opts, :max_memory_bytes)

    case :ecall_admission.admit(max_processes, max_run_queue, max_memory_bytes) do
      {:ok, _snapshot} ->
        :ok

      {:error, reason, _snapshot} ->
        Ecall.Metrics.inc(:call_admission_rejected_total)
        {:error, {:server_overloaded, reason}}
    end
  end

  defp admit_caller_rate(caller_id) do
    interval_ms =
      Application.get_env(:ecall, __MODULE__, [])
      |> Keyword.get(:call_initiate_interval_ms)

    case :ecall_gate.allow({:call_initiate, to_string(caller_id)}, interval_ms) do
      :ok ->
        :ok

      {:error, :rate_limited} ->
        Ecall.Metrics.inc(:call_rate_limited_total)
        {:error, :rate_limited}
    end
  end

  defp admit_active_calls do
    case Application.get_env(:ecall, __MODULE__, []) |> Keyword.get(:max_active_calls) do
      nil ->
        :ok

      max_active_calls when is_integer(max_active_calls) and max_active_calls > 0 ->
        if active_call_count() >= max_active_calls do
          Ecall.Metrics.inc(:call_admission_rejected_total)
          {:error, {:server_overloaded, :active_call_limit}}
        else
          :ok
        end

      _invalid ->
        :ok
    end
  end

  defp active_call_count do
    Call
    |> where([c], c.status in ^@active_statuses)
    |> Repo.aggregate(:count, :id)
  end
end
