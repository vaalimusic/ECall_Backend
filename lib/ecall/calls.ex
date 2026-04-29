defmodule Ecall.Calls do
  import Ecto.Query

  alias Ecall.Calls.{Call, Registry}
  alias Ecall.Repo

  @timeout_ms 30_000
  @active_statuses [:initiated, :ringing, :accepted]

  def initiate(caller_id, %{"to" => callee_id, "media" => media}) when media in ["audio", "video"] do
    caller_id = to_string(caller_id)
    callee_id = to_string(callee_id)
    media_type = media_type(media)

    if caller_id == callee_id do
      {:error, :cannot_call_self}
    else
      do_initiate(caller_id, callee_id, media_type)
    end
  end

  def initiate(_caller_id, _payload), do: {:error, :invalid_payload}

  defp do_initiate(caller_id, callee_id, media_type) do
    attrs = %{
      caller_id: caller_id,
      callee_id: callee_id,
      media_type: media_type,
      status: :ringing,
      started_at: DateTime.utc_now()
    }

    Repo.transaction(fn ->
      case active_between(caller_id, callee_id, media_type) do
        %Call{} = call ->
          {:reused, call}

        nil ->
          call =
            %Call{}
            |> Call.changeset(attrs)
            |> Repo.insert!()

          Registry.start_call(call.id, call.caller_id, call.callee_id, @timeout_ms)
          {:created, call}
      end
    end)
  end

  def list_for_user(user_id, limit \\ 50) do
    Call
    |> where([c], c.caller_id == ^to_string(user_id) or c.callee_id == ^to_string(user_id))
    |> order_by([c], desc: c.inserted_at)
    |> limit(^limit)
    |> Repo.all()
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

  def join(call_id, user_id), do: Registry.join(call_id, user_id)
  def leave(call_id, user_id), do: Registry.leave(call_id, user_id)

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
            update_call(call, :missed, terminal_attrs(:missed))

          %Call{} = call ->
            {:ok, call}

          nil ->
            {:error, :not_found}
        end
      end)

    with {:ok, {:ok, %Call{} = call}} <- result do
      Registry.update_status(call_id, call.status)
      broadcast_call_event(call, "call:timeout", nil)
    end

    unwrap_transaction(result)
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
      Registry.update_status(call.id, call.status)
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

  defp ensure_status(%Call{status: status}, allowed_from) when status in allowed_from, do: :ok
  defp ensure_status(%Call{status: status}, _allowed_from), do: {:error, {:invalid_transition, status}}

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
