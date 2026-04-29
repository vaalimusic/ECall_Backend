defmodule Ecall.MessagingTest do
  use Ecall.DataCase, async: true

  alias Ecall.Messaging

  test "creates and lists text messages" do
    assert {:ok, message} = Messaging.create_message("1", %{"to" => "2", "body" => "hello"})
    assert message.sender_id == "1"
    assert message.recipient_id == "2"

    assert [listed] = Messaging.list_conversation("1", "2")
    assert listed.id == message.id
  end

  test "syncs user messages after timestamp" do
    since = DateTime.utc_now() |> DateTime.add(-60, :second)
    assert {:ok, new_message} = Messaging.create_message("2", %{"to" => "1", "body" => "new"})

    assert [synced] = Messaging.sync_for_user("1", since)
    assert synced.id == new_message.id
  end

  test "reuses message with the same client_message_id" do
    payload = %{"to" => "2", "body" => "hello", "client_message_id" => "client-msg-1"}

    assert {:ok, first} = Messaging.create_message("1", payload)
    assert {:ok, second} = Messaging.create_message("1", payload)

    assert second.id == first.id
    assert second.client_message_id == "client-msg-1"
    assert [_one_message] = Messaging.list_conversation("1", "2")
  end

  test "creates idempotent voice note message" do
    payload = %{
      "to" => "2",
      "type" => "voice_note",
      "client_message_id" => "voice-note-1",
      "metadata" => %{
        "media_url" => "https://cdn.example.test/voice/1.ogg",
        "duration_ms" => 12_000,
        "size_bytes" => 48_000,
        "sha256" => "abc123",
        "mime_type" => "audio/ogg; codecs=opus"
      }
    }

    assert {:ok, first} = Messaging.create_message("1", payload)
    assert {:ok, second} = Messaging.create_message("1", payload)

    assert first.id == second.id
    assert first.type == :voice_note
    assert first.metadata["duration_ms"] == 12_000
  end
end
