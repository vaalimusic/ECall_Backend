defmodule Ecall.Repo.Migrations.CreateCalls do
  use Ecto.Migration

  def change do
    create table(:calls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :caller_id, :string, null: false
      add :callee_id, :string, null: false
      add :media_type, :string, null: false
      add :status, :string, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :answered_at, :utc_datetime_usec
      add :ended_at, :utc_datetime_usec
      add :duration_seconds, :integer, null: false, default: 0
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:calls, [:caller_id, :inserted_at])
    create index(:calls, [:callee_id, :inserted_at])
    create index(:calls, [:status])
  end
end
