defmodule EcallWeb.RateLimitPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    scale_ms = Application.get_env(:ecall, __MODULE__, [])[:scale_ms] || 60_000
    limit = Application.get_env(:ecall, __MODULE__, [])[:limit] || 600
    key = client_ip(conn)

    case Hammer.check_rate("http:#{key}", scale_ms, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{error: "rate_limited"}))
        |> halt()
    end
  end

  defp client_ip(%Plug.Conn{remote_ip: remote_ip}), do: remote_ip |> Tuple.to_list() |> Enum.join(".")
end
