defmodule EcallWeb.CallController do
  use EcallWeb, :controller

  alias Ecall.Calls

  def index(conn, %{"user_id" => user_id} = params) do
    if conn.assigns.current_user.id == user_id do
      limit = params |> Map.get("limit", "50") |> String.to_integer()
      calls = Calls.list_for_user(user_id, min(limit, 200))
      json(conn, %{data: Enum.map(calls, &call_json/1)})
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "forbidden"})
    end
  end

  defp call_json(call) do
    %{
      id: call.id,
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
end
