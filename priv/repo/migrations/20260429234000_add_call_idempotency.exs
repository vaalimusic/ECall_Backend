defmodule Ecall.Repo.Migrations.AddCallIdempotency do
  use Ecto.Migration

  def change do
    alter table(:calls) do
      add :client_call_id, :string
    end

    create unique_index(:calls, [:caller_id, :client_call_id],
             where: "client_call_id IS NOT NULL",
             name: :calls_caller_client_call_id_unique
           )
  end
end
