defmodule Ecall.Repo.Migrations.CreateCallParticipants do
  use Ecto.Migration

  def change do
    create table(:call_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :call_id, references(:calls, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, :string, null: false
      add :joined_at, :utc_datetime_usec, null: false
      add :last_seen_at, :utc_datetime_usec, null: false
      add :left_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:call_participants, [:call_id, :user_id],
             name: :call_participants_call_id_user_id_unique
           )

    create index(:call_participants, [:user_id, :last_seen_at])
    create index(:call_participants, [:call_id, :left_at])
  end
end
