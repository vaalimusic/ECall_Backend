defmodule Ecall.Messaging.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string

  schema "messages" do
    field :sender_id, :string
    field :recipient_id, :string
    field :type, Ecto.Enum, values: [:text, :service, :voice_note]
    field :body, :string
    field :client_message_id, :string
    field :metadata, :map, default: %{}
    field :delivered_at, :utc_datetime_usec
    field :read_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:sender_id, :recipient_id, :type, :body, :client_message_id, :metadata, :delivered_at, :read_at])
    |> validate_required([:sender_id, :recipient_id, :type])
    |> validate_length(:client_message_id, max: 128)
    |> unique_constraint(:client_message_id, name: :messages_sender_client_message_id_unique)
    |> validate_body()
  end

  defp validate_body(%Ecto.Changeset{changes: %{type: :text}} = changeset) do
    changeset
    |> validate_required([:body])
    |> validate_length(:body, max: 4_000)
  end

  defp validate_body(%Ecto.Changeset{changes: %{type: :voice_note}} = changeset) do
    changeset
    |> validate_required([:metadata])
    |> validate_voice_note_metadata()
  end

  defp validate_body(changeset), do: changeset

  defp validate_voice_note_metadata(changeset) do
    metadata = get_field(changeset, :metadata) || %{}

    cond do
      not is_map(metadata) ->
        add_error(changeset, :metadata, "must be an object")

      not valid_voice_note_string?(metadata["media_url"]) ->
        add_error(changeset, :metadata, "media_url is required")

      not valid_voice_note_integer?(metadata["duration_ms"], 1, 120_000) ->
        add_error(changeset, :metadata, "duration_ms must be between 1 and 120000")

      not valid_voice_note_integer?(metadata["size_bytes"], 1, 2_000_000) ->
        add_error(changeset, :metadata, "size_bytes must be between 1 and 2000000")

      not valid_voice_note_string?(metadata["sha256"]) ->
        add_error(changeset, :metadata, "sha256 is required")

      true ->
        changeset
    end
  end

  defp valid_voice_note_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp valid_voice_note_string?(_value), do: false

  defp valid_voice_note_integer?(value, min, max) when is_integer(value), do: value >= min and value <= max
  defp valid_voice_note_integer?(_value, _min, _max), do: false
end
