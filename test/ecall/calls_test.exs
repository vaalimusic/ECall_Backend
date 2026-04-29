defmodule Ecall.CallsTest do
  use Ecall.DataCase, async: false

  alias Ecall.Calls

  test "initiates call and stores call history" do
    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert call.status == :ringing
    assert Calls.participant?(call.id, "1")
    assert Calls.participant?(call.id, "2")
    assert Calls.joinable?(call.id, "1")
  end

  test "reuses active call between the same users" do
    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert {:ok, {:reused, reused_call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert reused_call.id == call.id
  end

  test "ends call without crashing" do
    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert {:ok, ended_call} = Calls.handle_event(call.id, "1", "call:end", %{})
    assert ended_call.status == :ended
    refute Calls.joinable?(call.id, "1")
  end

  test "only callee can accept ringing call" do
    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert {:error, :forbidden_actor} = Calls.handle_event(call.id, "1", "call:accept", %{})
    assert {:ok, accepted_call} = Calls.handle_event(call.id, "2", "call:accept", %{})
    assert accepted_call.status == :accepted
  end

  test "terminal calls reject later state changes" do
    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert {:ok, ended_call} = Calls.handle_event(call.id, "1", "call:end", %{})
    assert ended_call.status == :ended
    assert {:error, {:invalid_transition, :ended}} = Calls.handle_event(call.id, "2", "call:accept", %{})
  end

  test "after terminal state a new call can be created" do
    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert {:ok, _ended_call} = Calls.handle_event(call.id, "1", "call:end", %{})
    assert {:ok, {:created, new_call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert new_call.id != call.id
  end
end
