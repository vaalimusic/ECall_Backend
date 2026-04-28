defmodule Ecall.Push.DeviceToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "device_tokens" do
    field :user_id, :string
    field :token, :string
    field :platform, Ecto.Enum, values: [:ios, :android, :web]
    field :last_seen_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(device_token, attrs) do
    device_token
    |> cast(attrs, [:user_id, :token, :platform, :last_seen_at])
    |> validate_required([:user_id, :token, :platform])
    |> unique_constraint(:token)
  end
end
