defmodule Ecall.Calls.Participant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "call_participants" do
    field :call_id, :binary_id
    field :user_id, :string
    field :joined_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :left_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:call_id, :user_id, :joined_at, :last_seen_at, :left_at])
    |> validate_required([:call_id, :user_id, :joined_at, :last_seen_at])
    |> unique_constraint(:user_id, name: :call_participants_call_id_user_id_unique)
  end
end
