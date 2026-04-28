defmodule EcallWeb.MessageController do
  use EcallWeb, :controller

  alias Ecall.Messaging
  alias Ecall.Push
  alias EcallWeb.Presence

  def index(conn, %{"user_id" => user_id, "peer_id" => peer_id} = params) do
    if current_user_id(conn) == user_id do
      limit = params |> Map.get("limit", "50") |> String.to_integer()
      messages = Messaging.list_conversation(user_id, peer_id, min(limit, 200))
      json(conn, %{data: Enum.map(messages, &Messaging.to_payload/1)})
    else
      forbidden(conn)
    end
  end

  def create(conn, params) do
    case Messaging.create_message(current_user_id(conn), params) do
      {:ok, message} ->
        payload = Messaging.to_payload(message)
        EcallWeb.Endpoint.broadcast("user:#{message.recipient_id}", "message:new", payload)
        maybe_push_message(message)
        json(conn, %{data: payload})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: EcallWeb.ChangesetJSON.errors(changeset)})
    end
  end

  defp current_user_id(conn), do: conn.assigns.current_user.id

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
end
