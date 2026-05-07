defmodule EcallWeb.MetricsAuthPlug do
  def init(opts), do: opts

  def call(conn, _opts) do
    Plug.BasicAuth.basic_auth(conn,
      username: System.get_env("METRICS_USERNAME", "metrics"),
      password: System.get_env("METRICS_PASSWORD", "change-me")
    )
  end
end
