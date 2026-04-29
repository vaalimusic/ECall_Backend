defmodule EcallWeb.MessageController do
  use EcallWeb, :controller

  alias Ecall.Messaging
  alias Ecall.Push
  alias EcallWeb.ParamHelpers
  alias EcallWeb.Presence

  def index(conn, %{"user_id" => user_id, "peer_id" => peer_id} = params) do
    if current_user_id(conn) == user_id do
      with {:ok, limit} <- ParamHelpers.parse_limit(params, default: 50, max: 200) do
        messages = Messaging.list_conversation(user_id, peer_id, limit)
        json(conn, %{data: Enum.map(messages, &Messaging.to_payload/1)})
      else
        {:error, :invalid_limit} -> bad_request(conn, "invalid_limit")
      end
    else
      forbidden(conn)
    end
  end

  def sync(conn, %{"user_id" => user_id} = params) do
    if current_user_id(conn) == user_id do
      with {:ok, since} <- parse_since(Map.get(params, "since")),
           {:ok, limit} <- parse_limit(Map.get(params, "limit", "200")) do
        messages = Messaging.sync_for_user(user_id, since, limit)
        payloads = Enum.map(messages, &Messaging.to_payload/1)

        Ecall.Metrics.inc(:message_sync_total)

        json(conn, %{
          data: payloads,
          next_since: next_since(payloads, since)
        })
      else
        {:error, :invalid_since} ->
          bad_request(conn, "invalid_since")

        {:error, :invalid_limit} ->
          bad_request(conn, "invalid_limit")
      end
    else
      forbidden(conn)
    end
  end

  def create(conn, params) do
    case Messaging.create_message_with_status(current_user_id(conn), params) do
      {:ok, state, message} ->
        if state == :created, do: Ecall.Metrics.inc(:message_created_total)
        payload = Messaging.to_payload(message)
        maybe_broadcast_message(state, message, payload)
        json(conn, %{data: payload})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: EcallWeb.ChangesetJSON.errors(changeset)})
    end
  end

  defp current_user_id(conn), do: conn.assigns.current_user.id

  defp parse_since(nil), do: {:ok, nil}
  defp parse_since(""), do: {:ok, nil}

  defp parse_since(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _reason} -> {:error, :invalid_since}
    end
  end

  defp parse_limit(value) when is_binary(value) do
    case Integer.parse(value) do
      {limit, ""} when limit > 0 -> {:ok, min(limit, 500)}
      _ -> {:error, :invalid_limit}
    end
  end

  defp next_since([], nil), do: DateTime.utc_now() |> DateTime.to_iso8601()
  defp next_since([], %DateTime{} = since), do: DateTime.to_iso8601(since)
  defp next_since(payloads, _since), do: payloads |> List.last() |> Map.fetch!(:inserted_at)

  defp maybe_broadcast_message(:created, message, payload) do
    EcallWeb.Endpoint.broadcast("user:#{message.recipient_id}", "message:new", payload)
    maybe_push_message(message)
  end

  defp maybe_broadcast_message(:reused, _message, _payload), do: :ok

  defp maybe_push_message(message) do
    unless Presence.online?(message.recipient_id) do
      Push.deliver(message.recipient_id, :new_message, %{message_id: message.id, from: message.sender_id})
    end
  end

  defp forbidden(conn) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "forbidden"})
  end

  defp bad_request(conn, error) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: error})
  end
end
