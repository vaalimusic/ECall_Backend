defmodule Ecall.Repo.Migrations.AddMessageIdempotency do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :client_message_id, :string
    end

    create unique_index(:messages, [:sender_id, :client_message_id],
             where: "client_message_id IS NOT NULL",
             name: :messages_sender_client_message_id_unique
           )
  end
end
