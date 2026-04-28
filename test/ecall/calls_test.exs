defmodule Ecall.CallsTest do
  use Ecall.DataCase, async: false

  alias Ecall.Calls

  test "initiates call and stores call history" do
    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert call.status == :ringing
    assert Calls.participant?(call.id, "1")
    assert Calls.participant?(call.id, "2")
  end

  test "reuses active call between the same users" do
    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert {:ok, {:reused, reused_call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert reused_call.id == call.id
  end
end
