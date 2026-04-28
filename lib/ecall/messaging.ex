defmodule Ecall.Messaging do
  import Ecto.Query

  alias Ecall.Messaging.Message
  alias Ecall.Repo

  def create_message(sender_id, %{"to" => recipient_id, "body" => body}) do
    %Message{}
    |> Message.changeset(%{
      sender_id: to_string(sender_id),
      recipient_id: to_string(recipient_id),
      type: :text,
      body: body,
      metadata: %{}
    })
    |> Repo.insert()
  end

  def create_service_message(sender_id, recipient_id, body, metadata \\ %{}) do
    %Message{}
    |> Message.changeset(%{
      sender_id: to_string(sender_id),
      recipient_id: to_string(recipient_id),
      type: :service,
      body: body,
      metadata: metadata
    })
    |> Repo.insert()
  end

  def list_conversation(user_id, peer_id, limit \\ 50) do
    user_id = to_string(user_id)
    peer_id = to_string(peer_id)

    Message
    |> where([m], (m.sender_id == ^user_id and m.recipient_id == ^peer_id) or (m.sender_id == ^peer_id and m.recipient_id == ^user_id))
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  def mark_delivered(id, recipient_id) do
    mark(id, recipient_id, :delivered_at)
  end

  def mark_read(id, recipient_id) do
    now = DateTime.utc_now()

    Message
    |> where([m], m.id == ^id and m.recipient_id == ^to_string(recipient_id))
    |> Repo.update_all(set: [delivered_at: now, read_at: now])
  end

  def to_payload(%Message{} = message) do
    %{
      id: message.id,
      from: message.sender_id,
      to: message.recipient_id,
      type: message.type,
      body: message.body,
      metadata: message.metadata,
      inserted_at: DateTime.to_iso8601(message.inserted_at)
    }
  end

  defp mark(id, recipient_id, field) do
    Message
    |> where([m], m.id == ^id and m.recipient_id == ^to_string(recipient_id))
    |> Repo.update_all(set: [{field, DateTime.utc_now()}])
  end
end
