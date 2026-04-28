defmodule Ecall.Calls do
  import Ecto.Query

  alias Ecall.Calls.{Call, Registry}
  alias Ecall.Repo

  @timeout_ms 30_000

  def initiate(caller_id, %{"to" => callee_id, "media" => media}) when media in ["audio", "video"] do
    attrs = %{
      caller_id: to_string(caller_id),
      callee_id: to_string(callee_id),
      media_type: media_type(media),
      status: :ringing,
      started_at: DateTime.utc_now()
    }

    Repo.transaction(fn ->
      call =
        %Call{}
        |> Call.changeset(attrs)
        |> Repo.insert!()

      Registry.start_call(call.id, call.caller_id, call.callee_id, @timeout_ms)
      call
    end)
  end

  def initiate(_caller_id, _payload), do: {:error, :invalid_payload}

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

  def join(call_id, user_id), do: Registry.join(call_id, user_id)
  def leave(call_id, user_id), do: Registry.leave(call_id, user_id)

  def handle_event(call_id, user_id, "call:accept", _payload) do
    update_status(call_id, user_id, :accepted, answered_at: DateTime.utc_now())
  end

  def handle_event(call_id, user_id, "call:reject", _payload), do: update_status(call_id, user_id, :rejected)
  def handle_event(call_id, user_id, "call:busy", _payload), do: update_status(call_id, user_id, :busy)
  def handle_event(call_id, user_id, "call:timeout", _payload), do: update_status(call_id, user_id, :timeout)

  def handle_event(call_id, user_id, "call:end", _payload) do
    now = DateTime.utc_now()

    call_id
    |> Repo.get(Call)
    |> case do
      nil ->
        {:error, :not_found}

      %Call{} = call ->
        duration =
          call.answered_at
          |> duration_seconds(now)

        update_status(call_id, user_id, :ended, ended_at: now, duration_seconds: duration)
    end
  end

  def handle_event(_call_id, _user_id, _event, _payload), do: :ok

  def mark_timeout(call_id) do
    call_id
    |> Repo.get(Call)
    |> case do
      %Call{status: status} = call when status in [:ringing, :initiated] ->
        call
        |> Call.changeset(%{status: :missed, ended_at: DateTime.utc_now()})
        |> Repo.update()

      %Call{} = call ->
        {:ok, call}

      nil ->
        {:error, :not_found}
    end
  end

  defp update_status(call_id, user_id, status, attrs \\ []) do
    with %Call{} = call <- Repo.get(Call, call_id),
         true <- participant?(call_id, user_id) do
      attrs = attrs |> Enum.into(%{}) |> Map.put(:status, status)

      call
      |> Call.changeset(attrs)
      |> Repo.update()
      |> tap(fn _ -> Registry.update_status(call_id, status) end)
    else
      false -> {:error, :forbidden}
      nil -> {:error, :not_found}
    end
  end

  defp duration_seconds(nil, _ended_at), do: 0
  defp duration_seconds(answered_at, ended_at), do: DateTime.diff(ended_at, answered_at, :second)
  defp media_type("audio"), do: :audio
  defp media_type("video"), do: :video
end
