defmodule Ecall.CallsTest do
  use Ecall.DataCase, async: false

  alias Ecall.Calls

  test "initiates call and stores call history" do
    assert {:ok, call} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert call.status == :ringing
    assert Calls.participant?(call.id, "1")
    assert Calls.participant?(call.id, "2")
  end
end
