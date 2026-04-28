defmodule Ecall.Calls.Call do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string

  schema "calls" do
    field :caller_id, :string
    field :callee_id, :string
    field :media_type, Ecto.Enum, values: [:audio, :video]
    field :status, Ecto.Enum, values: [:initiated, :ringing, :accepted, :rejected, :busy, :ended, :timeout, :missed]
    field :started_at, :utc_datetime_usec
    field :answered_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :duration_seconds, :integer, default: 0
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(call, attrs) do
    call
    |> cast(attrs, [:caller_id, :callee_id, :media_type, :status, :started_at, :answered_at, :ended_at, :duration_seconds, :metadata])
    |> validate_required([:caller_id, :callee_id, :media_type, :status, :started_at])
    |> validate_number(:duration_seconds, greater_than_or_equal_to: 0)
  end
end
