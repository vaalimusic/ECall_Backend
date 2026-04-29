defmodule EcallWeb.CallControllerTest do
  use EcallWeb.ConnCase, async: false

  alias Ecall.Auth
  alias Ecall.Calls

  setup do
    assert {:ok, session} =
             Auth.register(%{
               "email" => "calls@example.com",
               "password" => "super-secret"
             })

    conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("authorization", "Bearer #{session.access_token}")

    {:ok, conn: conn, user: session.user}
  end

  test "GET /api/users/:user_id/calls/active returns active call", %{conn: conn, user: user} do
    assert {:ok, {:created, call}} = Calls.initiate(user.id, %{"to" => "peer", "media" => "video"})

    conn = get(conn, ~p"/api/users/#{user.id}/calls/active")

    assert %{
             "data" => %{
               "id" => id,
               "status" => "ringing"
             }
           } = json_response(conn, 200)

    assert id == call.id
  end

  test "GET /api/users/:user_id/calls/active returns null without active call", %{conn: conn, user: user} do
    conn = get(conn, ~p"/api/users/#{user.id}/calls/active")
    assert json_response(conn, 200) == %{"data" => nil}
  end

  test "GET /api/calls/:id returns call for participant", %{conn: conn, user: user} do
    assert {:ok, {:created, call}} = Calls.initiate(user.id, %{"to" => "peer", "media" => "video"})

    conn = get(conn, ~p"/api/calls/#{call.id}")

    assert %{"data" => %{"id" => id}} = json_response(conn, 200)
    assert id == call.id
  end

  test "GET /api/users/:user_id/calls rejects invalid limit", %{conn: conn, user: user} do
    conn = get(conn, ~p"/api/users/#{user.id}/calls?limit=bad")
    assert json_response(conn, 400) == %{"error" => "invalid_limit"}
  end
end
