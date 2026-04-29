defmodule Ecall.Messaging do
  import Ecto.Query

  alias Ecall.Messaging.Message
  alias Ecall.Repo

  def create_message(sender_id, payload) do
    case create_message_with_status(sender_id, payload) do
      {:ok, _state, message} -> {:ok, message}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def create_message_with_status(sender_id, %{"to" => recipient_id, "body" => body} = payload) do
    sender_id = to_string(sender_id)

    attrs = %{
      sender_id: sender_id,
      recipient_id: to_string(recipient_id),
      type: :text,
      body: body,
      client_message_id: normalize_client_message_id(Map.get(payload, "client_message_id")),
      metadata: %{}
    }

    insert_or_reuse_message(sender_id, attrs)
  end

  def create_message_with_status(sender_id, %{"to" => recipient_id, "type" => "voice_note", "metadata" => metadata} = payload) do
    sender_id = to_string(sender_id)

    attrs = %{
      sender_id: sender_id,
      recipient_id: to_string(recipient_id),
      type: :voice_note,
      body: Map.get(payload, "body"),
      client_message_id: normalize_client_message_id(Map.get(payload, "client_message_id")),
      metadata: normalize_voice_note_metadata(metadata)
    }

    insert_or_reuse_message(sender_id, attrs)
  end

  def create_service_message(sender_id, recipient_id, body, metadata \\ %{}) do
    %Message{}
    |> Message.changeset(%{
      sender_id: to_string(sender_id),
      recipient_id: to_string(recipient_id),
      type: :service,
      body: body,
      client_message_id: nil,
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

  def sync_for_user(user_id, since, limit \\ 200) do
    user_id = to_string(user_id)
    limit = limit |> max(1) |> min(500)

    query =
      Message
      |> where([m], m.sender_id == ^user_id or m.recipient_id == ^user_id)
      |> order_by([m], asc: m.inserted_at)
      |> limit(^limit)

    query =
      case since do
        nil -> query
        %DateTime{} = since -> where(query, [m], m.inserted_at > ^since)
      end

    Repo.all(query)
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
      client_message_id: message.client_message_id,
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

  defp insert_or_reuse_message(sender_id, attrs) do
    case %Message{} |> Message.changeset(attrs) |> Repo.insert() do
      {:ok, message} ->
        {:ok, :created, message}

      {:error, changeset} ->
        case attrs[:client_message_id] do
          nil -> {:error, changeset}
          client_message_id -> find_by_client_message_id(sender_id, client_message_id, changeset)
        end
    end
  end

  defp find_by_client_message_id(sender_id, client_message_id, changeset) do
    case Repo.get_by(Message, sender_id: sender_id, client_message_id: client_message_id) do
      %Message{} = message -> {:ok, :reused, message}
      nil -> {:error, changeset}
    end
  end

  defp normalize_client_message_id(%{"client_message_id" => client_message_id}), do: normalize_client_message_id(client_message_id)
  defp normalize_client_message_id(value) when is_binary(value), do: value |> String.trim() |> blank_to_nil()
  defp normalize_client_message_id(_value), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp normalize_voice_note_metadata(metadata) when is_map(metadata) do
    %{
      "media_url" => metadata["media_url"],
      "duration_ms" => metadata["duration_ms"],
      "size_bytes" => metadata["size_bytes"],
      "sha256" => metadata["sha256"],
      "mime_type" => Map.get(metadata, "mime_type", "audio/ogg; codecs=opus")
    }
  end

  defp normalize_voice_note_metadata(_metadata), do: %{}
end
