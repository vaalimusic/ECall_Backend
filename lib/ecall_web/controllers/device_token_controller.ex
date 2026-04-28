defmodule EcallWeb.DeviceTokenController do
  use EcallWeb, :controller

  alias Ecall.Push

  def create(conn, %{"user_id" => user_id} = params) do
    if conn.assigns.current_user.id == user_id do
      case Push.upsert_device_token(user_id, params) do
        {:ok, token} -> json(conn, %{data: %{id: token.id, platform: token.platform}})
        {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: EcallWeb.ChangesetJSON.errors(changeset)})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "forbidden"})
    end
  end
end
