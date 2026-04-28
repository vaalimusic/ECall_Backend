defmodule Ecall.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "users" do
    field :email, :string
    field :phone, :string
    field :display_name, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :confirmed_at, :utc_datetime_usec
    field :disabled_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :phone, :display_name, :password])
    |> normalize_email()
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:password, min: 8, max: 128)
    |> validate_length(:display_name, max: 120)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name, :phone])
    |> validate_length(:display_name, max: 120)
  end

  defp normalize_email(changeset) do
    update_change(changeset, :email, fn email ->
      email
      |> String.trim()
      |> String.downcase()
    end)
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Argon2.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
