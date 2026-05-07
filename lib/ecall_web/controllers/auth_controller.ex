defmodule EcallWeb.AuthController do
  use EcallWeb, :controller

  alias Ecall.Auth

  def register(conn, params) do
    case Auth.register(params, request_meta(conn)) do
      {:ok, session} ->
        conn
        |> put_status(:created)
        |> json(session_json(session))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: EcallWeb.ChangesetJSON.errors(changeset)})
    end
  end

  def login(conn, params) do
    case Auth.login(params, request_meta(conn)) do
      {:ok, session} ->
        json(conn, session_json(session))

      {:error, reason} when reason in [:invalid_credentials, :user_disabled] ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_credentials"})
    end
  end

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Auth.refresh(refresh_token, request_meta(conn)) do
      {:ok, session} ->
        json(conn, session_json(session))

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: to_string(reason)})
    end
  end

  def refresh(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "refresh_token_required"})
  end

  def logout(conn, %{"refresh_token" => refresh_token}) do
    Auth.logout(refresh_token)
    send_resp(conn, 204, "")
  end

  def logout(conn, _params), do: send_resp(conn, 204, "")

  def me(conn, _params) do
    json(conn, %{user: conn.assigns.current_user})
  end

  defp session_json(session) do
    %{
      user: session.user,
      access_token: session.access_token,
      token_type: "Bearer",
      expires_at: DateTime.to_iso8601(session.access_token_expires_at),
      refresh_token: session.refresh_token
    }
  end

  defp request_meta(conn) do
    %{
      user_agent: conn |> get_req_header("user-agent") |> List.first(),
      ip_address: conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    }
  end
end
