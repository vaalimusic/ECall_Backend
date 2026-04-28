defmodule EcallWeb.AuthPlug do
  import Plug.Conn

  alias Ecall.Auth
  alias Ecall.Auth.Token

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, raw_token} <- fetch_bearer_token(conn),
         {:ok, user_id} <- Token.verify(raw_token),
         %{} = user <- Auth.get_user(user_id),
         true <- is_nil(user.disabled_at) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
        |> halt()
    end
  end

  defp fetch_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      ["bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing_bearer_token}
    end
  end
end
