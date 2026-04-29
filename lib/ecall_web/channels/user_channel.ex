defmodule EcallWeb.UserChannel do
  use EcallWeb, :channel

  alias Ecall.{Calls, Messaging, Push}

  @impl true
  def join("user:" <> user_id, _payload, %{assigns: %{user_id: user_id}} = socket) do
    send(self(), :after_join)
    {:ok, %{user_id: user_id}, socket}
  end

  def join("user:" <> _user_id, _payload, _socket) do
    Ecall.Metrics.inc(:channel_join_forbidden_total)
    {:error, %{reason: "forbidden"}}
  end

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
    with {:ok, {state, call}} <- Calls.initiate(socket.assigns.user_id, payload) do
      event = %{"call_id" => call.id, "client_call_id" => call.client_call_id, "from" => call.caller_id, "media" => call.media_type}

      if state == :created do
        EcallWeb.Endpoint.broadcast("user:#{call.callee_id}", "call:ringing", event)
        maybe_push_incoming_call(call)
      end

      {:reply, {:ok, event}, socket}
    else
      {:error, reason} -> {:reply, {:error, call_error(reason)}, socket}
    end
  end

  def handle_in("message:new", payload, socket) do
    with {:ok, state, message} <- Messaging.create_message_with_status(socket.assigns.user_id, payload) do
      event = Messaging.to_payload(message)
      if state == :created do
        EcallWeb.Endpoint.broadcast("user:#{message.recipient_id}", "message:new", event)
        maybe_push_message(message)
      end

      {:reply, {:ok, event}, socket}
    else
      {:error, changeset} -> {:reply, {:error, %{errors: EcallWeb.ChangesetJSON.errors(changeset)}}, socket}
    end
  end

  def handle_in("call:ringing_ack", %{"call_id" => call_id}, socket) do
    case Calls.ringing_ack(call_id, socket.assigns.user_id) do
      {:ok, call} ->
        {:reply, {:ok, %{"call_id" => call.id, "status" => to_string(call.status)}}, socket}

      {:error, reason} ->
        {:reply, {:error, call_error(reason)}, socket}
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

  defp call_error({:server_overloaded, detail}), do: %{reason: "server_overloaded", detail: to_string(detail)}
  defp call_error(:rate_limited), do: %{reason: "rate_limited"}
  defp call_error(:callee_busy), do: %{reason: "callee_busy"}
  defp call_error(:caller_has_active_call), do: %{reason: "caller_has_active_call"}
  defp call_error(reason), do: %{reason: inspect(reason)}
end
