defmodule Ecall.Push.Job do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "push_jobs" do
    field :user_id, :string
    field :type, :string
    field :payload, :map, default: %{}
    field :status, Ecto.Enum, values: [:pending, :delivered, :failed], default: :pending
    field :attempts, :integer, default: 0
    field :next_attempt_at, :utc_datetime_usec
    field :last_error, :string

    belongs_to :device_token, Ecall.Push.DeviceToken

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [:device_token_id, :user_id, :type, :payload, :status, :attempts, :next_attempt_at, :last_error])
    |> validate_required([:device_token_id, :user_id, :type, :payload, :status, :attempts, :next_attempt_at])
    |> validate_number(:attempts, greater_than_or_equal_to: 0)
  end
end
