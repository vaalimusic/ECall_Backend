defmodule Ecall.Repo.Migrations.CreateDeviceTokens do
  use Ecto.Migration

  def change do
    create table(:device_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :string, null: false
      add :token, :text, null: false
      add :platform, :string, null: false
      add :last_seen_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:device_tokens, [:token])
    create index(:device_tokens, [:user_id])
  end
end
