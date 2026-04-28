defmodule EcallWeb.UserChannel do
  use EcallWeb, :channel

  alias Ecall.{Calls, Messaging, Push}

  @impl true
  def join("user:" <> user_id, _payload, %{assigns: %{user_id: user_id}} = socket) do
    send(self(), :after_join)
    {:ok, %{user_id: user_id}, socket}
  end

  def join("user:" <> _user_id, _payload, _socket), do: {:error, %{reason: "forbidden"}}

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id

    {:ok, _} =
      Presence.track(socket, user_id, %{
        online_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        device_id: socket.assigns[:device_id]
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  @impl true
  def handle_in("call:initiate", payload, socket) do
    with {:ok, call} <- Calls.initiate(socket.assigns.user_id, payload) do
      event = %{"call_id" => call.id, "from" => call.caller_id, "media" => call.media_type}
      EcallWeb.Endpoint.broadcast("user:#{call.callee_id}", "call:ringing", event)
      maybe_push_incoming_call(call)
      {:reply, {:ok, event}, socket}
    else
      {:error, reason} -> {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  def handle_in("message:new", payload, socket) do
    with {:ok, message} <- Messaging.create_message(socket.assigns.user_id, payload) do
      event = Messaging.to_payload(message)
      EcallWeb.Endpoint.broadcast("user:#{message.recipient_id}", "message:new", event)
      maybe_push_message(message)
      {:reply, {:ok, event}, socket}
    else
      {:error, changeset} -> {:reply, {:error, %{errors: EcallWeb.ChangesetJSON.errors(changeset)}}, socket}
    end
  end

  def handle_in("message:delivered", %{"message_id" => id}, socket) do
    Messaging.mark_delivered(id, socket.assigns.user_id)
    {:reply, :ok, socket}
  end

  def handle_in("message:read", %{"message_id" => id}, socket) do
    Messaging.mark_read(id, socket.assigns.user_id)
    {:reply, :ok, socket}
  end

  defp maybe_push_incoming_call(call) do
    unless Presence.online?(call.callee_id) do
      Push.deliver(call.callee_id, :incoming_call, %{call_id: call.id, from: call.caller_id})
    end
  end

  defp maybe_push_message(message) do
    unless Presence.online?(message.recipient_id) do
      Push.deliver(message.recipient_id, :new_message, %{message_id: message.id, from: message.sender_id})
    end
  end
end
