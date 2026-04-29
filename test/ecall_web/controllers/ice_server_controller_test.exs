defmodule EcallWeb.IceServerControllerTest do
  use EcallWeb.ConnCase, async: false

  alias Ecall.Auth

  setup do
    env = %{
      "TURN_HOST" => System.get_env("TURN_HOST"),
      "TURN_USER" => System.get_env("TURN_USER"),
      "TURN_PASSWORD" => System.get_env("TURN_PASSWORD"),
      "STUN_URLS" => System.get_env("STUN_URLS"),
      "TURN_URLS" => System.get_env("TURN_URLS")
    }

    on_exit(fn ->
      Enum.each(env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)

    :ok
  end

  test "GET /api/webrtc/ice_servers returns authenticated ICE config", %{conn: conn} do
    System.put_env("TURN_HOST", "turn.example.com")
    System.put_env("TURN_USER", "ecall")
    System.put_env("TURN_PASSWORD", "secret")
    System.delete_env("STUN_URLS")
    System.delete_env("TURN_URLS")

    assert {:ok, session} =
             Auth.register(%{
               "email" => "ice@example.com",
               "password" => "super-secret"
             })

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{session.access_token}")
      |> get(~p"/api/webrtc/ice_servers")

    assert %{
             "data" => [
               %{"urls" => "stun:turn.example.com:3478"},
               %{
                 "urls" => [
                   "turn:turn.example.com:3478?transport=udp",
                   "turn:turn.example.com:3478?transport=tcp"
                 ],
                 "username" => "ecall",
                 "credential" => "secret"
               }
             ]
           } = json_response(conn, 200)
  end
end
