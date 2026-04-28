defmodule Ecall.Repo.Migrations.CreateUsersAndRefreshTokens do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :phone, :string
      add :display_name, :string
      add :password_hash, :text, null: false
      add :confirmed_at, :utc_datetime_usec
      add :disabled_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:email])
    create index(:users, [:phone])

    create table(:refresh_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token_hash, :text, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :revoked_at, :utc_datetime_usec
      add :replaced_by_token_id, :binary_id
      add :user_agent, :text
      add :ip_address, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:refresh_tokens, [:token_hash])
    create index(:refresh_tokens, [:user_id])
    create index(:refresh_tokens, [:expires_at])
  end
end
