defmodule EcallWeb.HealthControllerTest do
  use EcallWeb.ConnCase, async: true

  test "GET /api/health", %{conn: conn} do
    conn = get(conn, ~p"/api/health")
    assert json_response(conn, 200) == %{"status" => "ok"}
  end

  test "GET /api/health/live", %{conn: conn} do
    conn = get(conn, ~p"/api/health/live")
    assert json_response(conn, 200) == %{"status" => "ok"}
  end

  test "GET /api/health/ready", %{conn: conn} do
    conn = get(conn, ~p"/api/health/ready")

    assert %{
             "status" => "ok",
             "checks" => %{
               "cluster" => "ok",
               "database" => "ok",
               "endpoint" => "ok",
               "pubsub" => "ok"
             },
             "cluster" => %{
               "connected_nodes" => [],
               "min_size" => 1,
               "size" => 1
             }
           } = json_response(conn, 200)
  end
end
