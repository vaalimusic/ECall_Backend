defmodule EcallWeb.CallChannel do
  use EcallWeb, :channel

  alias Ecall.Calls

  @max_sdp_bytes 128_000
  @max_ice_candidate_bytes 8_000
  @events ~w(call:accept call:reject call:busy call:end call:timeout call:mute call:unmute call:video_on call:video_off call:switch_camera call:reconnecting call:reconnected webrtc:offer webrtc:answer webrtc:ice)

  @impl true
  def join("call:" <> call_id, _payload, socket) do
    if Calls.joinable?(call_id, socket.assigns.user_id) do
      case Calls.join(call_id, socket.assigns.user_id) do
        :ok -> {:ok, %{call_id: call_id}, assign(socket, :call_id, call_id)}
        {:error, reason} -> {:error, %{reason: inspect(reason)}}
      end
    else
      Ecall.Metrics.inc(:channel_join_forbidden_total)
      {:error, %{reason: "forbidden_or_inactive_call"}}
    end
  end

  @impl true
  def handle_in(event, payload, socket) when event in @events do
    started_at = System.monotonic_time()
    call_id = socket.assigns.call_id
    user_id = socket.assigns.user_id

    result =
      with :ok <- validate_payload(event, payload) do
        Calls.handle_event(call_id, user_id, event, payload)
      end

    if result == :ok, do: record_handover_metric(event)

    if signaling_event?(event) and result == :ok do
      broadcast_from!(socket, event, Map.merge(payload, %{"from" => user_id, "call_id" => call_id}))
    end

    :telemetry.execute(
      [:ecall, :signaling, :event],
      %{latency: System.monotonic_time() - started_at},
      %{event: event, call_id: call_id}
    )

    case result do
      {:error, reason} ->
        Ecall.Metrics.inc(:signaling_errors_total)
        {:reply, {:error, %{reason: inspect(reason)}}, socket}

      _ -> {:reply, :ok, socket}
    end
  end

  def handle_in("call:heartbeat", _payload, socket) do
    case Calls.heartbeat(socket.assigns.call_id, socket.assigns.user_id) do
      :ok -> {:reply, :ok, socket}
      {:error, reason} -> {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  def handle_in(_event, _payload, socket) do
    Ecall.Metrics.inc(:signaling_errors_total)
    {:reply, {:error, %{reason: "unsupported_event"}}, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:call_id], do: Calls.leave(socket.assigns.call_id, socket.assigns.user_id)
    :ok
  end

  defp signaling_event?(event) do
    event in ~w(call:mute call:unmute call:video_on call:video_off call:switch_camera call:reconnecting call:reconnected webrtc:offer webrtc:answer webrtc:ice)
  end

  defp record_handover_metric("call:reconnecting"), do: Ecall.Metrics.inc(:call_reconnecting_total)
  defp record_handover_metric("call:reconnected"), do: Ecall.Metrics.inc(:call_reconnected_total)
  defp record_handover_metric(_event), do: :ok

  defp validate_payload(event, %{"sdp" => sdp}) when event in ["webrtc:offer", "webrtc:answer"] and is_binary(sdp) do
    if byte_size(sdp) <= @max_sdp_bytes, do: :ok, else: {:error, :sdp_too_large}
  end

  defp validate_payload(event, _payload) when event in ["webrtc:offer", "webrtc:answer"], do: {:error, :invalid_sdp}

  defp validate_payload("webrtc:ice", %{"candidate" => candidate}) when is_binary(candidate) do
    if byte_size(candidate) <= @max_ice_candidate_bytes, do: :ok, else: {:error, :ice_candidate_too_large}
  end

  defp validate_payload("webrtc:ice", _payload), do: {:error, :invalid_ice_candidate}
  defp validate_payload(_event, _payload), do: :ok
end
