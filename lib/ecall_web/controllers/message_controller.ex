defmodule EcallWeb.MessageController do
  use EcallWeb, :controller

  alias Ecall.Messaging

  def index(conn, %{"user_id" => user_id, "peer_id" => peer_id} = params) do
    limit = params |> Map.get("limit", "50") |> String.to_integer()
    messages = Messaging.list_conversation(user_id, peer_id, min(limit, 200))
    json(conn, %{data: Enum.map(messages, &Messaging.to_payload/1)})
  end

  def create(conn, %{"from" => sender_id} = params) do
    case Messaging.create_message(sender_id, params) do
      {:ok, message} -> json(conn, %{data: Messaging.to_payload(message)})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: EcallWeb.ChangesetJSON.errors(changeset)})
    end
  end
end
