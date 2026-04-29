defmodule EcallWeb.HealthController do
  use EcallWeb, :controller

  def show(conn, _params), do: json(conn, %{status: "ok"})

  def live(conn, _params), do: json(conn, %{status: "ok"})

  def turn(conn, _params) do
    case Ecall.TurnHealth.check() do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", reason: inspect(reason)})
    end
  end

  def ready(conn, _params) do
    checks = %{
      database: database_ready?(),
      pubsub: process_ready?(Ecall.PubSub),
      endpoint: process_ready?(EcallWeb.Endpoint),
      cluster: cluster_ready?()
    }

    if Enum.all?(checks, fn {_name, status} -> status == :ok end) do
      json(conn, %{status: "ok", checks: checks, cluster: cluster_info()})
    else
      conn
      |> put_status(:service_unavailable)
      |> json(%{status: "error", checks: checks, cluster: cluster_info()})
    end
  end

  defp database_ready? do
    case Ecto.Adapters.SQL.query(Ecall.Repo, "SELECT 1", [], timeout: 1_000) do
      {:ok, _result} -> :ok
      {:error, _reason} -> :error
    end
  rescue
    _error -> :error
  end

  defp process_ready?(name) do
    if Process.whereis(name), do: :ok, else: :error
  end

  defp cluster_ready? do
    if cluster_size() >= cluster_min_size(), do: :ok, else: :error
  end

  defp cluster_info do
    %{
      node: Atom.to_string(Node.self()),
      connected_nodes: Enum.map(Node.list(), &Atom.to_string/1),
      size: cluster_size(),
      min_size: cluster_min_size()
    }
  end

  defp cluster_size, do: 1 + length(Node.list())

  defp cluster_min_size do
    Application.get_env(:ecall, :cluster_min_size, 1)
  end
end
