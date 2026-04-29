defmodule EcallWeb.CallController do
  use EcallWeb, :controller

  alias Ecall.Calls
  alias EcallWeb.ParamHelpers

  def index(conn, %{"user_id" => user_id} = params) do
    if conn.assigns.current_user.id == user_id do
      with {:ok, limit} <- ParamHelpers.parse_limit(params, default: 50, max: 200) do
        calls = Calls.list_for_user(user_id, limit)
        json(conn, %{data: Enum.map(calls, &call_json/1)})
      else
        {:error, :invalid_limit} -> bad_request(conn, "invalid_limit")
      end
    else
      forbidden(conn)
    end
  end

  def active(conn, %{"user_id" => user_id}) do
    if conn.assigns.current_user.id == user_id do
      case Calls.active_for_user(user_id) do
        nil -> json(conn, %{data: nil})
        call -> json(conn, %{data: call_json(call)})
      end
    else
      forbidden(conn)
    end
  end

  def show(conn, %{"id" => call_id}) do
    case Calls.get_for_user(call_id, conn.assigns.current_user.id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found"})

      call ->
        json(conn, %{data: call_json(call)})
    end
  end

  defp call_json(call) do
    %{
      id: call.id,
      client_call_id: call.client_call_id,
      caller_id: call.caller_id,
      callee_id: call.callee_id,
      media_type: call.media_type,
      status: call.status,
      started_at: iso(call.started_at),
      answered_at: iso(call.answered_at),
      ended_at: iso(call.ended_at),
      duration_seconds: call.duration_seconds
    }
  end

  defp iso(nil), do: nil
  defp iso(datetime), do: DateTime.to_iso8601(datetime)

  defp forbidden(conn) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "forbidden"})
  end

  defp bad_request(conn, error) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: error})
  end
end
