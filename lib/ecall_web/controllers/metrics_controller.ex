defmodule EcallWeb.MetricsController do
  use EcallWeb, :controller

  def show(conn, _params) do
    body = """
    # HELP ecall_calls_active_count Active in-memory calls on this node.
    # TYPE ecall_calls_active_count gauge
    ecall_calls_active_count #{Ecall.Calls.Registry.active_count()}
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, body)
  end
end
