defmodule Ecall.Push.FcmClient do
  require Logger

  def deliver(device_token, type, payload) do
    project_id = Application.get_env(:ecall, __MODULE__)[:project_id]
    access_token = Application.get_env(:ecall, __MODULE__)[:access_token]

    if project_id && access_token do
      request = build_request(project_id, access_token, device_token.token, type, payload)
      Finch.request(request, Ecall.Finch)
    else
      Logger.warning("FCM is not configured, skipping push type=#{type} user_id=#{device_token.user_id}")
      :ok
    end
  end

  defp build_request(project_id, access_token, token, type, payload) do
    url = "https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send"
    body = Jason.encode!(%{message: %{token: token, data: stringify(Map.put(payload, :type, type))}})

    Finch.build(:post, url, [{"authorization", "Bearer #{access_token}"}, {"content-type", "application/json"}], body)
  end

  defp stringify(map), do: Map.new(map, fn {key, value} -> {to_string(key), to_string(value)} end)
end
