defmodule EcallWeb.MetricsController do
  use EcallWeb, :controller

  def show(conn, _params) do
    admission = Ecall.Admission.snapshot()

    body = """
    # HELP ecall_calls_active_count Active in-memory calls on this node.
    # TYPE ecall_calls_active_count gauge
    ecall_calls_active_count #{Ecall.Calls.Registry.active_count()}
    # HELP ecall_call_participants_active_count Active call channel participants stored in Postgres.
    # TYPE ecall_call_participants_active_count gauge
    ecall_call_participants_active_count #{Ecall.Calls.active_participant_count()}
    # HELP ecall_call_initiated_total Calls created on this node.
    # TYPE ecall_call_initiated_total counter
    ecall_call_initiated_total #{metric(:call_initiated_total)}
    # HELP ecall_call_reused_total Active calls reused on this node.
    # TYPE ecall_call_reused_total counter
    ecall_call_reused_total #{metric(:call_reused_total)}
    # HELP ecall_call_accepted_total Calls accepted on this node.
    # TYPE ecall_call_accepted_total counter
    ecall_call_accepted_total #{metric(:call_accepted_total)}
    # HELP ecall_call_rejected_total Calls rejected on this node.
    # TYPE ecall_call_rejected_total counter
    ecall_call_rejected_total #{metric(:call_rejected_total)}
    # HELP ecall_call_busy_total Calls marked busy on this node.
    # TYPE ecall_call_busy_total counter
    ecall_call_busy_total #{metric(:call_busy_total)}
    # HELP ecall_call_ended_total Calls ended on this node.
    # TYPE ecall_call_ended_total counter
    ecall_call_ended_total #{metric(:call_ended_total)}
    # HELP ecall_call_missed_total Calls missed or timed out on this node.
    # TYPE ecall_call_missed_total counter
    ecall_call_missed_total #{metric(:call_missed_total)}
    # HELP ecall_signaling_errors_total Signaling errors on this node.
    # TYPE ecall_signaling_errors_total counter
    ecall_signaling_errors_total #{metric(:signaling_errors_total)}
    # HELP ecall_message_created_total Messages created on this node.
    # TYPE ecall_message_created_total counter
    ecall_message_created_total #{metric(:message_created_total)}
    # HELP ecall_message_sync_total Message sync requests handled on this node.
    # TYPE ecall_message_sync_total counter
    ecall_message_sync_total #{metric(:message_sync_total)}
    # HELP ecall_push_delivered_total Push notifications accepted by the adapter on this node.
    # TYPE ecall_push_delivered_total counter
    ecall_push_delivered_total #{metric(:push_delivered_total)}
    # HELP ecall_push_failed_total Push notifications failed without invalid-token cleanup on this node.
    # TYPE ecall_push_failed_total counter
    ecall_push_failed_total #{metric(:push_failed_total)}
    # HELP ecall_push_invalid_token_total Push notifications that removed invalid device tokens on this node.
    # TYPE ecall_push_invalid_token_total counter
    ecall_push_invalid_token_total #{metric(:push_invalid_token_total)}
    # HELP ecall_push_retry_delivered_total Push retry jobs delivered on this node.
    # TYPE ecall_push_retry_delivered_total counter
    ecall_push_retry_delivered_total #{metric(:push_retry_delivered_total)}
    # HELP ecall_push_retry_failed_total Push retry job attempts failed on this node.
    # TYPE ecall_push_retry_failed_total counter
    ecall_push_retry_failed_total #{metric(:push_retry_failed_total)}
    # HELP ecall_push_retry_pending_count Pending durable push retry jobs.
    # TYPE ecall_push_retry_pending_count gauge
    ecall_push_retry_pending_count #{Ecall.Push.pending_jobs_count()}
    # HELP ecall_websocket_auth_rejected_total WebSocket auth rejections on this node.
    # TYPE ecall_websocket_auth_rejected_total counter
    ecall_websocket_auth_rejected_total #{metric(:websocket_auth_rejected_total)}
    # HELP ecall_channel_join_forbidden_total Forbidden channel joins on this node.
    # TYPE ecall_channel_join_forbidden_total counter
    ecall_channel_join_forbidden_total #{metric(:channel_join_forbidden_total)}
    # HELP ecall_call_reconnecting_total Call network handover reconnecting events on this node.
    # TYPE ecall_call_reconnecting_total counter
    ecall_call_reconnecting_total #{metric(:call_reconnecting_total)}
    # HELP ecall_call_reconnected_total Call network handover reconnected events on this node.
    # TYPE ecall_call_reconnected_total counter
    ecall_call_reconnected_total #{metric(:call_reconnected_total)}
    # HELP ecall_call_admission_rejected_total Call starts rejected before overload could hurt existing calls.
    # TYPE ecall_call_admission_rejected_total counter
    ecall_call_admission_rejected_total #{metric(:call_admission_rejected_total)}
    # HELP ecall_call_rate_limited_total New call starts rejected because one caller is retrying too fast.
    # TYPE ecall_call_rate_limited_total counter
    ecall_call_rate_limited_total #{metric(:call_rate_limited_total)}
    # HELP ecall_call_ringing_ack_total Ringing delivery acknowledgements received from callees.
    # TYPE ecall_call_ringing_ack_total counter
    ecall_call_ringing_ack_total #{metric(:call_ringing_ack_total)}
    # HELP ecall_beam_process_count Erlang VM process count on this node.
    # TYPE ecall_beam_process_count gauge
    ecall_beam_process_count #{Map.fetch!(admission, :process_count)}
    # HELP ecall_beam_process_limit Erlang VM process limit on this node.
    # TYPE ecall_beam_process_limit gauge
    ecall_beam_process_limit #{Map.fetch!(admission, :process_limit)}
    # HELP ecall_beam_run_queue Erlang VM run queue length on this node.
    # TYPE ecall_beam_run_queue gauge
    ecall_beam_run_queue #{Map.fetch!(admission, :run_queue)}
    # HELP ecall_beam_total_memory_bytes Erlang VM total memory on this node.
    # TYPE ecall_beam_total_memory_bytes gauge
    ecall_beam_total_memory_bytes #{Map.fetch!(admission, :total_memory)}
    # HELP ecall_cluster_connected_nodes Connected Erlang cluster peers visible from this node.
    # TYPE ecall_cluster_connected_nodes gauge
    ecall_cluster_connected_nodes #{length(Node.list())}
    # HELP ecall_cluster_size Total Erlang cluster size including this node.
    # TYPE ecall_cluster_size gauge
    ecall_cluster_size #{1 + length(Node.list())}
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, body)
  end

  defp metric(name), do: Ecall.Metrics.get(name)
end
