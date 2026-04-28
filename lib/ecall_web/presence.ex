defmodule EcallWeb.Presence do
  use Phoenix.Presence,
    otp_app: :ecall,
    pubsub_server: Ecall.PubSub

  def online?(user_id) do
    "user:#{user_id}"
    |> list()
    |> Map.has_key?(to_string(user_id))
  end
end
