defmodule Ecall.Push do
  import Ecto.Query

  alias Ecall.Push.{DeviceToken, Job}
  alias Ecall.Repo

  @max_attempts 8

  def upsert_device_token(user_id, attrs) do
    attrs =
      attrs
      |> Map.put("user_id", to_string(user_id))
      |> Map.put("last_seen_at", DateTime.utc_now())

    %DeviceToken{}
    |> DeviceToken.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [user_id: attrs["user_id"], platform: attrs["platform"], last_seen_at: attrs["last_seen_at"], updated_at: DateTime.utc_now()]],
      conflict_target: :token
    )
  end

  def deliver(user_id, type, payload) do
    tokens =
      DeviceToken
      |> where([d], d.user_id == ^to_string(user_id))
      |> Repo.all()

    adapter = Application.get_env(:ecall, Ecall.Push.FcmClient, [])[:adapter] || Ecall.Push.LogClient

    Enum.each(tokens, fn token ->
      case adapter.deliver(token, type, payload) do
        :ok ->
          Ecall.Metrics.inc(:push_delivered_total)

        {:error, :invalid_token} ->
          Ecall.Metrics.inc(:push_invalid_token_total)
          delete_device_token(token)

        {:error, reason} ->
          Ecall.Metrics.inc(:push_failed_total)
          enqueue_retry(token, type, payload, reason)
      end
    end)

    :ok
  end

  def enqueue_retry(%DeviceToken{} = token, type, payload, reason \\ nil) do
    %Job{}
    |> Job.changeset(%{
      device_token_id: token.id,
      user_id: token.user_id,
      type: to_string(type),
      payload: stringify_payload(payload),
      status: :pending,
      attempts: 0,
      next_attempt_at: DateTime.utc_now(),
      last_error: stringify_error(reason)
    })
    |> Repo.insert()
  end

  def process_due_jobs(limit \\ 50) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      jobs =
        Job
        |> where([j], j.status == :pending and j.next_attempt_at <= ^now)
        |> order_by([j], asc: j.next_attempt_at)
        |> limit(^limit)
        |> lock("FOR UPDATE SKIP LOCKED")
        |> Repo.all()
        |> Repo.preload(:device_token)

      Enum.reduce(jobs, 0, fn job, count ->
        process_job(job)
        count + 1
      end)
    end)
    |> case do
      {:ok, count} -> count
      {:error, _reason} -> 0
    end
  end

  def pending_jobs_count do
    Job
    |> where([j], j.status == :pending)
    |> Repo.aggregate(:count)
  end

  def delete_device_token(%DeviceToken{} = token) do
    Repo.delete(token)
    :ok
  end

  defp process_job(%Job{device_token: nil} = job) do
    mark_job_failed(job, :device_token_missing)
  end

  defp process_job(%Job{} = job) do
    adapter = Application.get_env(:ecall, Ecall.Push.FcmClient, [])[:adapter] || Ecall.Push.LogClient

    case adapter.deliver(job.device_token, job.type, job.payload) do
      :ok ->
        Ecall.Metrics.inc(:push_retry_delivered_total)
        Repo.delete(job)

      {:error, :invalid_token} ->
        Ecall.Metrics.inc(:push_invalid_token_total)
        delete_device_token(job.device_token)

      {:error, reason} ->
        Ecall.Metrics.inc(:push_retry_failed_total)
        reschedule_or_fail_job(job, reason)
    end
  end

  defp reschedule_or_fail_job(%Job{} = job, reason) do
    attempts = job.attempts + 1

    if attempts >= @max_attempts do
      mark_job_failed(job, reason, attempts)
    else
      job
      |> Job.changeset(%{
        attempts: attempts,
        next_attempt_at: DateTime.add(DateTime.utc_now(), backoff_seconds(attempts), :second),
        last_error: stringify_error(reason)
      })
      |> Repo.update()
    end
  end

  defp mark_job_failed(%Job{} = job, reason, attempts \\ nil) do
    job
    |> Job.changeset(%{
      status: :failed,
      attempts: attempts || job.attempts,
      last_error: stringify_error(reason)
    })
    |> Repo.update()
  end

  defp backoff_seconds(attempts) do
    min(3_600, trunc(:math.pow(2, attempts)) * 30)
  end

  defp stringify_payload(payload), do: Map.new(payload, fn {key, value} -> {to_string(key), value} end)
  defp stringify_error(nil), do: nil
  defp stringify_error(reason), do: inspect(reason)
end
