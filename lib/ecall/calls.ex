defmodule Ecall.Calls do
  import Ecto.Query

  alias Ecall.Calls.{Call, Participant, Registry}
  alias Ecall.Repo

  @timeout_ms 30_000
  @active_statuses [:initiated, :ringing, :accepted]

  def timeout_ms, do: @timeout_ms

  def initiate(caller_id, %{"to" => callee_id, "media" => media} = payload) when media in ["audio", "video"] do
    caller_id = to_string(caller_id)
    callee_id = to_string(callee_id)
    media_type = media_type(media)
    client_call_id = normalize_client_call_id(Map.get(payload, "client_call_id"))

    if caller_id == callee_id do
      {:error, :cannot_call_self}
    else
      do_initiate(caller_id, callee_id, media_type, client_call_id)
    end
  end

  def initiate(_caller_id, _payload), do: {:error, :invalid_payload}

  defp do_initiate(caller_id, callee_id, media_type, client_call_id) do
    attrs = %{
      caller_id: caller_id,
      callee_id: callee_id,
      media_type: media_type,
      status: :ringing,
      client_call_id: client_call_id,
      started_at: DateTime.utc_now()
    }

    result =
      Repo.transaction(fn ->
        case client_call(caller_id, client_call_id) || active_between(caller_id, callee_id, media_type) do
          %Call{} = call ->
            Ecall.Metrics.inc(:call_reused_total)
            {:reused, call}

          nil ->
            with :ok <- ensure_user_available(caller_id, :caller_has_active_call),
                 :ok <- ensure_user_available(callee_id, :callee_busy),
                 :ok <- Ecall.Admission.admit_call_start(caller_id) do
              insert_or_reuse_active_call(caller_id, callee_id, media_type, attrs)
            end
        end
      end)

    case result do
      {:ok, {:error, reason}} -> {:error, reason}
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_or_reuse_active_call(caller_id, callee_id, media_type, attrs) do
    case %Call{} |> Call.changeset(attrs) |> Repo.insert() do
      {:ok, call} ->
        Registry.start_call(call.id, call.caller_id, call.callee_id, @timeout_ms)
        Ecall.Metrics.inc(:call_initiated_total)
        {:created, call}

      {:error, _changeset} ->
        case client_call(caller_id, attrs.client_call_id) || active_between(caller_id, callee_id, media_type) do
          %Call{} = call ->
            Ecall.Metrics.inc(:call_reused_total)
            {:reused, call}

          nil -> {:error, :active_call_conflict}
        end
    end
  end

  def list_for_user(user_id, limit \\ 50) do
    Call
    |> where([c], c.caller_id == ^to_string(user_id) or c.callee_id == ^to_string(user_id))
    |> order_by([c], desc: c.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_for_user(call_id, user_id) do
    user_id = to_string(user_id)

    Call
    |> where([c], c.id == ^call_id)
    |> where([c], c.caller_id == ^user_id or c.callee_id == ^user_id)
    |> Repo.one()
  end

  def active_for_user(user_id) do
    user_id = to_string(user_id)

    Call
    |> where([c], c.status in ^@active_statuses)
    |> where([c], c.caller_id == ^user_id or c.callee_id == ^user_id)
    |> order_by([c], desc: c.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def participant?(call_id, user_id) do
    user_id = to_string(user_id)

    case Repo.get(Call, call_id) do
      %Call{caller_id: ^user_id} -> true
      %Call{callee_id: ^user_id} -> true
      _ -> false
    end
  end

  def joinable?(call_id, user_id) do
    user_id = to_string(user_id)

    case Repo.get(Call, call_id) do
      %Call{status: status, caller_id: ^user_id} when status in @active_statuses -> true
      %Call{status: status, callee_id: ^user_id} when status in @active_statuses -> true
      _ -> false
    end
  end

  def join(call_id, user_id) do
    Registry.join(call_id, user_id)
    upsert_participant(call_id, user_id)
  end

  def leave(call_id, user_id) do
    Registry.leave(call_id, user_id)
    mark_participant_left(call_id, user_id)
  end

  def heartbeat(call_id, user_id), do: touch_participant(call_id, user_id)

  def active_participant_count do
    cutoff = stale_participant_cutoff()

    Participant
    |> where([p], is_nil(p.left_at))
    |> where([p], p.last_seen_at > ^cutoff)
    |> Repo.aggregate(:count, :id)
  end

  def mark_stale_participants_left(now \\ DateTime.utc_now()) do
    cutoff = DateTime.add(now, -stale_participant_after_seconds(), :second)

    {count, _} =
      Participant
      |> where([p], is_nil(p.left_at))
      |> where([p], p.last_seen_at <= ^cutoff)
      |> Repo.update_all(set: [left_at: now, updated_at: now])

    count
  end

  def ringing_ack(call_id, user_id) do
    user_id = to_string(user_id)

    case get_call_for_update(call_id) do
      %Call{callee_id: ^user_id, status: status} = call when status in [:ringing, :accepted] ->
        Ecall.Metrics.inc(:call_ringing_ack_total)
        broadcast_call_event(call, "call:ringing_ack", user_id)
        {:ok, call}

      %Call{} ->
        {:error, :forbidden_or_not_ringing}

      nil ->
        {:error, :not_found}
    end
  end

  def handle_event(call_id, user_id, "call:accept", _payload) do
    transition(call_id, user_id, :accepted, allowed_from: [:ringing], actor: :callee, attrs: [answered_at: DateTime.utc_now()])
  end

  def handle_event(call_id, user_id, "call:reject", _payload) do
    transition(call_id, user_id, :rejected, allowed_from: [:ringing], actor: :callee, attrs: terminal_attrs(:rejected))
  end

  def handle_event(call_id, user_id, "call:busy", _payload) do
    transition(call_id, user_id, :busy, allowed_from: [:ringing], actor: :callee, attrs: terminal_attrs(:busy))
  end

  def handle_event(call_id, user_id, "call:timeout", _payload) do
    transition(call_id, user_id, :missed, allowed_from: [:ringing, :initiated], actor: :any, attrs: terminal_attrs(:missed))
  end

  def handle_event(call_id, user_id, "call:end", _payload) do
    now = DateTime.utc_now()
    transition(call_id, user_id, :ended, allowed_from: [:ringing, :accepted], actor: :any, attrs: [ended_at: now])
  end

  def handle_event(_call_id, _user_id, _event, _payload), do: :ok

  def mark_timeout(call_id) do
    result =
      Repo.transaction(fn ->
        call_id
        |> get_call_for_update()
        |> case do
          %Call{status: status} = call when status in [:ringing, :initiated] ->
            with {:ok, call} <- update_call(call, :missed, terminal_attrs(:missed)) do
              {:timed_out, call}
            end

          %Call{} = call ->
            {:ignored, call}

          nil ->
            {:error, :not_found}
        end
      end)

    with {:ok, {:timed_out, %Call{} = call}} <- result do
      Ecall.Metrics.inc(:call_missed_total)
      Registry.update_status(call_id, call.status)
      mark_all_participants_left(call.id)
      broadcast_call_event(call, "call:timeout", nil)
    end

    unwrap_transaction(result)
  end

  def mark_overdue_timeouts(now \\ DateTime.utc_now()) do
    cutoff = DateTime.add(now, -div(timeout_ms(), 1_000), :second)

    Call
    |> where([c], c.status in [:ringing, :initiated])
    |> where([c], c.started_at <= ^cutoff)
    |> order_by([c], asc: c.started_at)
    |> limit(100)
    |> Repo.all()
    |> Enum.reduce(0, fn call, count ->
      case mark_timeout(call.id) do
        {:timed_out, %Call{}} -> count + 1
        _ -> count
      end
    end)
  end

  defp transition(call_id, user_id, new_status, opts) do
    user_id = to_string(user_id)
    allowed_from = Keyword.fetch!(opts, :allowed_from)
    actor = Keyword.fetch!(opts, :actor)
    attrs = Keyword.get(opts, :attrs, [])

    result =
      Repo.transaction(fn ->
        case get_call_for_update(call_id) do
          nil ->
            {:error, :not_found}

          %Call{} = call ->
            with :ok <- ensure_participant(call, user_id),
                 :ok <- ensure_actor(call, user_id, actor),
                 :ok <- ensure_status(call, allowed_from) do
              update_call(call, new_status, attrs)
            end
        end
      end)

    with {:ok, {:ok, %Call{} = call}} <- result do
      record_call_transition_metric(call.status)
      Registry.update_status(call.id, call.status)
      if terminal_status?(call.status), do: mark_all_participants_left(call.id)
      broadcast_call_event(call, event_for_status(call.status), user_id)
    end

    unwrap_transaction(result)
  end

  defp get_call_for_update(call_id) do
    Call
    |> where([c], c.id == ^call_id)
    |> lock("FOR UPDATE")
    |> Repo.one()
  end

  defp ensure_participant(%Call{caller_id: user_id}, user_id), do: :ok
  defp ensure_participant(%Call{callee_id: user_id}, user_id), do: :ok
  defp ensure_participant(_call, _user_id), do: {:error, :forbidden}

  defp ensure_actor(_call, _user_id, :any), do: :ok
  defp ensure_actor(%Call{caller_id: user_id}, user_id, :caller), do: :ok
  defp ensure_actor(%Call{callee_id: user_id}, user_id, :callee), do: :ok
  defp ensure_actor(_call, _user_id, _actor), do: {:error, :forbidden_actor}

  defp ensure_status(%Call{status: status}, allowed_from) do
    if status in allowed_from do
      :ok
    else
      {:error, {:invalid_transition, status}}
    end
  end

  defp update_call(%Call{} = call, new_status, attrs) do
    attrs =
      attrs
      |> Enum.into(%{})
      |> Map.put(:status, new_status)
      |> maybe_put_duration(call)

    call
    |> Call.changeset(attrs)
    |> Repo.update()
  end

  defp maybe_put_duration(%{status: :ended, ended_at: ended_at} = attrs, %Call{answered_at: answered_at}) when not is_nil(ended_at) do
    Map.put(attrs, :duration_seconds, duration_seconds(answered_at, ended_at))
  end

  defp maybe_put_duration(attrs, _call), do: attrs

  defp terminal_attrs(reason), do: [ended_at: DateTime.utc_now(), metadata: %{reason: to_string(reason)}]

  defp event_for_status(:accepted), do: "call:accept"
  defp event_for_status(:rejected), do: "call:reject"
  defp event_for_status(:busy), do: "call:busy"
  defp event_for_status(:ended), do: "call:end"
  defp event_for_status(:missed), do: "call:timeout"
  defp event_for_status(:timeout), do: "call:timeout"

  defp record_call_transition_metric(:accepted), do: Ecall.Metrics.inc(:call_accepted_total)
  defp record_call_transition_metric(:rejected), do: Ecall.Metrics.inc(:call_rejected_total)
  defp record_call_transition_metric(:busy), do: Ecall.Metrics.inc(:call_busy_total)
  defp record_call_transition_metric(:ended), do: Ecall.Metrics.inc(:call_ended_total)
  defp record_call_transition_metric(:missed), do: Ecall.Metrics.inc(:call_missed_total)
  defp record_call_transition_metric(_status), do: :ok

  defp broadcast_call_event(%Call{} = call, event, actor_id) do
    payload = call_payload(call, actor_id)
    EcallWeb.Endpoint.broadcast("call:#{call.id}", event, payload)
    EcallWeb.Endpoint.broadcast("user:#{call.caller_id}", event, payload)
    EcallWeb.Endpoint.broadcast("user:#{call.callee_id}", event, payload)
  end

  defp call_payload(%Call{} = call, actor_id) do
    %{
      "call_id" => call.id,
      "from" => actor_id,
      "caller_id" => call.caller_id,
      "callee_id" => call.callee_id,
      "client_call_id" => call.client_call_id,
      "status" => to_string(call.status),
      "media" => to_string(call.media_type),
      "duration_seconds" => call.duration_seconds
    }
  end

  defp unwrap_transaction({:ok, result}), do: result
  defp unwrap_transaction({:error, reason}), do: {:error, reason}

  defp duration_seconds(nil, _ended_at), do: 0
  defp duration_seconds(answered_at, ended_at), do: DateTime.diff(ended_at, answered_at, :second)
  defp media_type("audio"), do: :audio
  defp media_type("video"), do: :video

  defp normalize_client_call_id(value) when is_binary(value), do: value |> String.trim() |> blank_to_nil()
  defp normalize_client_call_id(_value), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp client_call(_caller_id, nil), do: nil

  defp client_call(caller_id, client_call_id) do
    Call
    |> where([c], c.caller_id == ^caller_id and c.client_call_id == ^client_call_id)
    |> lock("FOR UPDATE")
    |> Repo.one()
  end

  defp upsert_participant(call_id, user_id) do
    now = DateTime.utc_now()

    attrs = %{
      call_id: call_id,
      user_id: to_string(user_id),
      joined_at: now,
      last_seen_at: now,
      left_at: nil
    }

    %Participant{}
    |> Participant.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [
          last_seen_at: now,
          left_at: nil,
          updated_at: now
        ]
      ],
      conflict_target: [:call_id, :user_id]
    )
    |> case do
      {:ok, _participant} -> :ok
      {:error, _changeset} -> {:error, :participant_join_failed}
    end
  end

  defp touch_participant(call_id, user_id) do
    now = DateTime.utc_now()

    {count, _} =
      Participant
      |> where([p], p.call_id == ^call_id and p.user_id == ^to_string(user_id))
      |> Repo.update_all(set: [last_seen_at: now, updated_at: now])

    if count > 0, do: :ok, else: upsert_participant(call_id, user_id)
  end

  defp mark_participant_left(call_id, user_id) do
    now = DateTime.utc_now()

    Participant
    |> where([p], p.call_id == ^call_id and p.user_id == ^to_string(user_id) and is_nil(p.left_at))
    |> Repo.update_all(set: [left_at: now, last_seen_at: now, updated_at: now])

    :ok
  end

  defp mark_all_participants_left(call_id) do
    now = DateTime.utc_now()

    Participant
    |> where([p], p.call_id == ^call_id and is_nil(p.left_at))
    |> Repo.update_all(set: [left_at: now, last_seen_at: now, updated_at: now])

    :ok
  end

  defp stale_participant_cutoff do
    DateTime.utc_now() |> DateTime.add(-stale_participant_after_seconds(), :second)
  end

  defp stale_participant_after_seconds do
    :ecall
    |> Application.get_env(Ecall.Calls.ParticipantSweeper, [])
    |> Keyword.get(:stale_after_seconds, 45)
  end

  defp terminal_status?(status), do: status in [:rejected, :busy, :ended, :timeout, :missed]

  defp ensure_user_available(user_id, reason) do
    case active_for_user_for_update(user_id) do
      nil -> :ok
      %Call{} -> {:error, reason}
    end
  end

  defp active_for_user_for_update(user_id) do
    user_id = to_string(user_id)

    Call
    |> where([c], c.status in ^@active_statuses)
    |> where([c], c.caller_id == ^user_id or c.callee_id == ^user_id)
    |> order_by([c], desc: c.inserted_at)
    |> limit(1)
    |> lock("FOR UPDATE")
    |> Repo.one()
  end

  defp active_between(caller_id, callee_id, media_type) do
    Call
    |> where([c], c.status in ^@active_statuses)
    |> where([c], c.media_type == ^media_type)
    |> where(
      [c],
      (c.caller_id == ^caller_id and c.callee_id == ^callee_id) or
        (c.caller_id == ^callee_id and c.callee_id == ^caller_id)
    )
    |> order_by([c], desc: c.inserted_at)
    |> limit(1)
    |> lock("FOR UPDATE")
    |> Repo.one()
  end
end
