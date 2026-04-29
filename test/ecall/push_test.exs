defmodule Ecall.PushTest do
  use Ecall.DataCase, async: false

  alias Ecall.Push
  alias Ecall.Push.{DeviceToken, Job}
  alias Ecall.Repo

  setup do
    previous = Application.get_env(:ecall, Ecall.Push.FcmClient)
    Application.put_env(:ecall, Ecall.Push.FcmClient, adapter: Ecall.Push.ResultClient)

    on_exit(fn ->
      if previous do
        Application.put_env(:ecall, Ecall.Push.FcmClient, previous)
      else
        Application.delete_env(:ecall, Ecall.Push.FcmClient)
      end
    end)

    :ok
  end

  test "removes invalid device tokens after push delivery" do
    assert {:ok, invalid} =
             Push.upsert_device_token("1", %{
               "token" => "invalid",
               "platform" => "ios"
             })

    assert :ok = Push.deliver("1", :new_message, %{message_id: "m1"})
    refute Repo.get(DeviceToken, invalid.id)
  end

  test "keeps retryable failed device tokens" do
    assert {:ok, failed} =
             Push.upsert_device_token("1", %{
               "token" => "failed",
               "platform" => "ios"
             })

    assert :ok = Push.deliver("1", :new_message, %{message_id: "m1"})
    assert Repo.get(DeviceToken, failed.id)
    assert Repo.aggregate(Job, :count) == 1
  end

  test "processes pending retry jobs and removes delivered jobs" do
    assert {:ok, token} =
             Push.upsert_device_token("1", %{
               "token" => "ok",
               "platform" => "ios"
             })

    assert {:ok, _job} = Push.enqueue_retry(token, :new_message, %{message_id: "m1"}, :temporary_failure)
    assert Push.process_due_jobs() == 1
    assert Repo.aggregate(Job, :count) == 0
  end
end
