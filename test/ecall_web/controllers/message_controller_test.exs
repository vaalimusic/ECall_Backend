defmodule EcallWeb.MessageControllerTest do
  use EcallWeb.ConnCase, async: false

  alias Ecall.Auth
  alias Ecall.Messaging

  setup do
    assert {:ok, session} =
             Auth.register(%{
               "email" => "messages@example.com",
               "password" => "super-secret"
             })

    conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("authorization", "Bearer #{session.access_token}")

    {:ok, conn: conn, user: session.user}
  end

  test "GET /api/users/:user_id/messages/sync returns user messages", %{conn: conn, user: user} do
    assert {:ok, message} = Messaging.create_message("peer", %{"to" => user.id, "body" => "hello"})

    conn = get(conn, ~p"/api/users/#{user.id}/messages/sync")

    assert %{
             "data" => [%{"id" => id, "body" => "hello"}],
             "next_since" => next_since
           } = json_response(conn, 200)

    assert id == message.id
    assert is_binary(next_since)
  end

  test "GET /api/users/:user_id/messages/sync rejects invalid since", %{conn: conn, user: user} do
    conn = get(conn, ~p"/api/users/#{user.id}/messages/sync?since=not-a-date")
    assert json_response(conn, 400) == %{"error" => "invalid_since"}
  end

  test "GET /api/users/:user_id/messages/sync rejects invalid limit", %{conn: conn, user: user} do
    conn = get(conn, ~p"/api/users/#{user.id}/messages/sync?limit=zero")
    assert json_response(conn, 400) == %{"error" => "invalid_limit"}
  end

  test "GET /api/users/:user_id/messages/sync rejects another user", %{conn: conn} do
    conn = get(conn, ~p"/api/users/someone-else/messages/sync")
    assert json_response(conn, 403) == %{"error" => "forbidden"}
  end

  test "GET /api/conversations/:user_id/:peer_id/messages rejects invalid limit", %{conn: conn, user: user} do
    conn = get(conn, ~p"/api/conversations/#{user.id}/peer/messages?limit=bad")
    assert json_response(conn, 400) == %{"error" => "invalid_limit"}
  end

  test "POST /api/messages is idempotent by client_message_id", %{conn: conn} do
    payload = %{"to" => "peer", "body" => "hello", "client_message_id" => "client-msg-1"}

    first_conn = post(conn, ~p"/api/messages", payload)
    second_conn = post(conn, ~p"/api/messages", payload)

    assert %{"data" => %{"id" => first_id, "client_message_id" => "client-msg-1"}} = json_response(first_conn, 200)
    assert %{"data" => %{"id" => second_id, "client_message_id" => "client-msg-1"}} = json_response(second_conn, 200)
    assert second_id == first_id
  end
end
