defmodule Ecall.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sender_id, :string, null: false
      add :recipient_id, :string, null: false
      add :type, :string, null: false
      add :body, :text
      add :metadata, :map, null: false, default: %{}
      add :delivered_at, :utc_datetime_usec
      add :read_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:messages, [:sender_id, :recipient_id, :inserted_at])
    create index(:messages, [:recipient_id, :sender_id, :inserted_at])
  end
end
