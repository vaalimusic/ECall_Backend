defmodule Ecall.Auth.RefreshToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "refresh_tokens" do
    field :token_hash, :string, redact: true
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    field :replaced_by_token_id, :binary_id
    field :user_agent, :string
    field :ip_address, :string

    belongs_to :user, Ecall.Auth.User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(refresh_token, attrs) do
    refresh_token
    |> cast(attrs, [:user_id, :token_hash, :expires_at, :revoked_at, :replaced_by_token_id, :user_agent, :ip_address])
    |> validate_required([:user_id, :token_hash, :expires_at])
    |> unique_constraint(:token_hash)
  end
end
