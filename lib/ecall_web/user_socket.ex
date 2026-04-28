defmodule EcallWeb.UserSocket do
  use Phoenix.Socket

  channel "user:*", EcallWeb.UserChannel
  channel "call:*", EcallWeb.CallChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case verify_token(token) do
      {:ok, user_id} -> {:ok, assign(socket, :user_id, to_string(user_id))}
      {:error, _reason} -> :error
    end
  end

  def connect(%{"user_id" => user_id}, socket, _connect_info) do
    if System.get_env("ALLOW_INSECURE_SOCKET_AUTH") == "true" do
      {:ok, assign(socket, :user_id, to_string(user_id))}
    else
      :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(%{assigns: %{user_id: user_id}}), do: "user_socket:#{user_id}"

  defp verify_token(token) do
    case Ecall.Auth.Token.verify(token) do
      {:ok, user_id} -> {:ok, user_id}
      {:error, _reason} -> Phoenix.Token.verify(EcallWeb.Endpoint, "user auth", token, max_age: 86_400)
    end
  end
end
