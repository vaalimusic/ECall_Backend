defmodule Ecall.Push do
  import Ecto.Query

  alias Ecall.Push.DeviceToken
  alias Ecall.Repo

  def upsert_device_token(user_id, attrs) do
    attrs =
      attrs
      |> Map.put("user_id", to_string(user_id))
      |> Map.put("last_seen_at", DateTime.utc_now())

    %DeviceToken{}
    |> DeviceToken.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [user_id: attrs["user_id"], platform: attrs["platform"], last_seen_at: attrs["last_seen_at"], updated_at: DateTime.utc_now()]],
      conflict_target: :token
    )
  end

  def deliver(user_id, type, payload) do
    tokens =
      DeviceToken
      |> where([d], d.user_id == ^to_string(user_id))
      |> Repo.all()

    adapter = Application.get_env(:ecall, Ecall.Push.FcmClient, [])[:adapter] || Ecall.Push.LogClient
    Enum.each(tokens, &adapter.deliver(&1, type, payload))
    :ok
  end
end
