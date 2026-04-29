defmodule Ecall.CallsTest do
  use Ecall.DataCase, async: false

  alias Ecall.Calls
  alias Ecall.Calls.Call
  alias Ecall.Repo

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

  test "reuses call with the same client_call_id" do
    payload = %{"to" => "2", "media" => "video", "client_call_id" => "local-call-1"}

    assert {:ok, {:created, call}} = Calls.initiate("1", payload)
    assert {:ok, {:reused, reused_call}} = Calls.initiate("1", payload)

    assert reused_call.id == call.id
    assert reused_call.client_call_id == "local-call-1"
  end

  test "rejects new call when active call admission limit is reached" do
    previous = Application.get_env(:ecall, Ecall.Admission, [])
    Application.put_env(:ecall, Ecall.Admission, Keyword.put(previous, :max_active_calls, 1))

    on_exit(fn ->
      Application.put_env(:ecall, Ecall.Admission, previous)
    end)

    assert {:ok, {:created, _call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert {:error, {:server_overloaded, :active_call_limit}} = Calls.initiate("3", %{"to" => "4", "media" => "video"})
  end

  test "rate limits new calls but allows idempotent retry" do
    previous = Application.get_env(:ecall, Ecall.Admission, [])
    Application.put_env(:ecall, Ecall.Admission, Keyword.put(previous, :call_initiate_interval_ms, 60_000))
    :ecall_gate.reset()

    on_exit(fn ->
      Application.put_env(:ecall, Ecall.Admission, previous)
      :ecall_gate.reset()
    end)

    payload = %{"to" => "2", "media" => "video", "client_call_id" => "retry-safe-call"}

    assert {:ok, {:created, call}} = Calls.initiate("1", payload)
    assert {:ok, {:reused, retry}} = Calls.initiate("1", payload)
    assert retry.id == call.id
    assert {:error, :rate_limited} = Calls.initiate("1", %{"to" => "3", "media" => "video", "client_call_id" => "new-call-too-fast"})
  end

  test "reuses active call when users are reversed" do
    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert {:ok, {:reused, reused_call}} = Calls.initiate("2", %{"to" => "1", "media" => "video"})
    assert reused_call.id == call.id
  end

  test "rejects new call when caller or callee is already in another active call" do
    assert {:ok, {:created, _call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert {:error, :caller_has_active_call} = Calls.initiate("1", %{"to" => "3", "media" => "video"})
    assert {:error, :callee_busy} = Calls.initiate("3", %{"to" => "2", "media" => "video"})
  end

  test "callee can acknowledge that ringing reached the device" do
    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})

    assert {:ok, acked_call} = Calls.ringing_ack(call.id, "2")
    assert acked_call.id == call.id
    assert {:error, :forbidden_or_not_ringing} = Calls.ringing_ack(call.id, "1")
  end

  test "persists call participant joins heartbeats and leaves" do
    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})

    assert :ok = Calls.join(call.id, "1")
    assert :ok = Calls.heartbeat(call.id, "1")
    assert Calls.active_participant_count() == 1

    assert :ok = Calls.leave(call.id, "1")
    assert Calls.active_participant_count() == 0
  end

  test "marks stale participants left" do
    previous = Application.get_env(:ecall, Ecall.Calls.ParticipantSweeper, [])
    Application.put_env(:ecall, Ecall.Calls.ParticipantSweeper, Keyword.put(previous, :stale_after_seconds, 1))

    on_exit(fn ->
      Application.put_env(:ecall, Ecall.Calls.ParticipantSweeper, previous)
    end)

    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert :ok = Calls.join(call.id, "1")

    now = DateTime.utc_now() |> DateTime.add(2, :second)
    assert Calls.mark_stale_participants_left(now) == 1
    assert Calls.active_participant_count() == 0
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

  test "marks overdue ringing calls as missed after restart-safe poll" do
    old_started_at = DateTime.utc_now() |> DateTime.add(-60, :second)

    call =
      %Call{}
      |> Call.changeset(%{
        caller_id: "1",
        callee_id: "2",
        media_type: :video,
        status: :ringing,
        started_at: old_started_at
      })
      |> Repo.insert!()

    assert Calls.mark_overdue_timeouts() == 1
    assert Repo.get!(Call, call.id).status == :missed
  end

  test "late timeout does not override terminal call state" do
    assert {:ok, {:created, call}} = Calls.initiate("1", %{"to" => "2", "media" => "video"})
    assert {:ok, ended_call} = Calls.handle_event(call.id, "1", "call:end", %{})
    assert ended_call.status == :ended

    assert {:ignored, ignored_call} = Calls.mark_timeout(call.id)
    assert ignored_call.status == :ended
  end
end
