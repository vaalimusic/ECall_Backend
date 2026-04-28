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
end
