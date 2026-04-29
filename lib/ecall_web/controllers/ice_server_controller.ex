defmodule EcallWeb.IceServerController do
  use EcallWeb, :controller

  def index(conn, _params) do
    json(conn, %{data: ice_servers()})
  end

  defp ice_servers do
    stun_servers() ++ turn_servers()
  end

  defp stun_servers do
    "STUN_URLS"
    |> split_env(default_stun_urls())
    |> Enum.map(&%{urls: &1})
  end

  defp turn_servers do
    username = System.get_env("TURN_USER")
    credential = System.get_env("TURN_PASSWORD")

    if present?(username) and present?(credential) do
      [
        %{
          urls: split_env("TURN_URLS", default_turn_urls()),
          username: username,
          credential: credential
        }
      ]
    else
      []
    end
  end

  defp default_stun_urls do
    "stun:#{turn_host()}:3478"
  end

  defp default_turn_urls do
    "turn:#{turn_host()}:3478?transport=udp,turn:#{turn_host()}:3478?transport=tcp"
  end

  defp turn_host do
    System.get_env("TURN_HOST") || System.get_env("PHX_HOST") || "localhost"
  end

  defp split_env(name, default) do
    name
    |> System.get_env(default)
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
