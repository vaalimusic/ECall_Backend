defmodule EcallWeb.AuthPlug do
  import Plug.Conn

  alias Ecall.Auth.Token

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, raw_token} <- fetch_bearer_token(conn),
         {:ok, user_id, claims} <- Token.verify_with_claims(raw_token) do
      conn
      |> assign(:current_user_id, user_id)
      |> assign(:current_user, current_user_from_claims(user_id, claims))
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
        |> halt()
    end
  end

  defp current_user_from_claims(user_id, claims) do
    %{
      id: user_id,
      email: Map.get(claims, "email"),
      phone: Map.get(claims, "phone"),
      display_name: Map.get(claims, "display_name")
    }
  end

  defp fetch_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      ["bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing_bearer_token}
    end
  end
end
