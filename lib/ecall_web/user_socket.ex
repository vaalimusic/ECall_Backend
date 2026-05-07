defmodule EcallWeb.UserSocket do
  use Phoenix.Socket
  require Logger

  channel "user:*", EcallWeb.UserChannel
  channel "call:*", EcallWeb.CallChannel

  @impl true
  def connect(params, socket, connect_info) do
    cond do
      token = socket_token(params, connect_info) ->
        connect_with_token(token, socket)

      true ->
        Ecall.Metrics.inc(:websocket_auth_rejected_total)
        Logger.warning("websocket auth rejected: missing token")
        :error
    end
  end

  @impl true
  def id(%{assigns: %{user_id: user_id}}), do: "user_socket:#{user_id}"

  defp connect_with_token(token, socket) do
    case verify_token(token) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, to_string(user_id))}

      {:error, reason} ->
        Ecall.Metrics.inc(:websocket_auth_rejected_total)
        Logger.warning("websocket auth rejected: #{inspect(reason)}")
        :error
    end
  end

  defp verify_token(token) do
    token = normalize_bearer_token(token)

    case Ecall.Auth.Token.verify(token) do
      {:ok, user_id} -> {:ok, user_id}
      {:error, jwt_reason} -> verify_phoenix_token(token, jwt_reason)
    end
  end

  defp verify_phoenix_token(token, jwt_reason) do
    case Phoenix.Token.verify(EcallWeb.Endpoint, "user auth", token, max_age: 86_400) do
      {:ok, user_id} -> {:ok, user_id}
      {:error, phoenix_reason} -> {:error, %{jwt: jwt_reason, phoenix: phoenix_reason}}
    end
  end

  defp socket_token(params, connect_info) do
    params["token"] ||
      params["access_token"] ||
      authorization_header_token(connect_info)
  end

  defp authorization_header_token(%{x_headers: headers}) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {"authorization", value} -> value
      {"Authorization", value} -> value
      _ -> nil
    end)
  end

  defp authorization_header_token(_connect_info), do: nil

  defp normalize_bearer_token(token) when is_binary(token) do
    token
    |> String.trim()
    |> String.replace_prefix("Bearer ", "")
    |> String.replace_prefix("bearer ", "")
  end
end
