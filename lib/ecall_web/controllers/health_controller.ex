defmodule EcallWeb.HealthController do
  use EcallWeb, :controller

  def show(conn, _params), do: json(conn, %{status: "ok"})
end
