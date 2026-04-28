defmodule Ecall.Messaging.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string

  schema "messages" do
    field :sender_id, :string
    field :recipient_id, :string
    field :type, Ecto.Enum, values: [:text, :service]
    field :body, :string
    field :metadata, :map, default: %{}
    field :delivered_at, :utc_datetime_usec
    field :read_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:sender_id, :recipient_id, :type, :body, :metadata, :delivered_at, :read_at])
    |> validate_required([:sender_id, :recipient_id, :type])
    |> validate_body()
  end

  defp validate_body(%Ecto.Changeset{changes: %{type: :text}} = changeset) do
    changeset
    |> validate_required([:body])
    |> validate_length(:body, max: 4_000)
  end

  defp validate_body(changeset), do: changeset
end
