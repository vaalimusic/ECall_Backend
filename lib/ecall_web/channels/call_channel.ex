defmodule EcallWeb.CallChannel do
  use EcallWeb, :channel

  alias Ecall.Calls

  @events ~w(call:accept call:reject call:busy call:end call:timeout call:mute call:unmute call:video_on call:video_off call:switch_camera webrtc:offer webrtc:answer webrtc:ice)

  @impl true
  def join("call:" <> call_id, _payload, socket) do
    if Calls.participant?(call_id, socket.assigns.user_id) do
      Calls.join(call_id, socket.assigns.user_id)
      {:ok, %{call_id: call_id}, assign(socket, :call_id, call_id)}
    else
      {:error, %{reason: "forbidden"}}
    end
  end

  @impl true
  def handle_in(event, payload, socket) when event in @events do
    started_at = System.monotonic_time()
    call_id = socket.assigns.call_id
    user_id = socket.assigns.user_id

    Calls.handle_event(call_id, user_id, event, payload)
    broadcast_from!(socket, event, Map.merge(payload, %{"from" => user_id, "call_id" => call_id}))

    :telemetry.execute(
      [:ecall, :signaling, :event],
      %{latency: System.monotonic_time() - started_at},
      %{event: event, call_id: call_id}
    )

    {:reply, :ok, socket}
  end

  def handle_in(_event, _payload, socket), do: {:reply, {:error, %{reason: "unsupported_event"}}, socket}

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:call_id], do: Calls.leave(socket.assigns.call_id, socket.assigns.user_id)
    :ok
  end
end
