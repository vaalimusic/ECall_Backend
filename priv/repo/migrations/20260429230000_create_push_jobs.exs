defmodule Ecall.Repo.Migrations.CreatePushJobs do
  use Ecto.Migration

  def change do
    create table(:push_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :device_token_id, references(:device_tokens, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, :string, null: false
      add :type, :string, null: false
      add :payload, :map, null: false, default: %{}
      add :status, :string, null: false, default: "pending"
      add :attempts, :integer, null: false, default: 0
      add :next_attempt_at, :utc_datetime_usec, null: false
      add :last_error, :text

      timestamps(type: :utc_datetime_usec)
    end

    create index(:push_jobs, [:status, :next_attempt_at])
    create index(:push_jobs, [:user_id])
    create index(:push_jobs, [:device_token_id])
  end
end
