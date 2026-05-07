defmodule Ecall.Push.FcmClient do
  require Logger

  def deliver(device_token, type, payload) do
    project_id = Application.get_env(:ecall, __MODULE__)[:project_id]

    with true <- present?(project_id),
         {:ok, access_token} <- access_token() do
      project_id
      |> build_request(access_token, device_token.token, type, payload)
      |> Finch.request(Ecall.Finch)
      |> normalize_response()
    else
      _ ->
        Logger.warning("FCM is not configured, skipping push type=#{type} user_id=#{device_token.user_id}")
        :ok
    end
  end

  defp build_request(project_id, access_token, token, type, payload) do
    url = "https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send"
    body = Jason.encode!(%{message: %{token: token, data: stringify(Map.put(payload, :type, type))}})

    Finch.build(:post, url, [{"authorization", "Bearer #{access_token}"}, {"content-type", "application/json"}], body)
  end

  defp access_token do
    cond do
      Process.whereis(Ecall.Goth) ->
        case Goth.fetch(Ecall.Goth) do
          {:ok, token} -> {:ok, token.token}
          {:error, reason} -> {:error, reason}
        end

      present?(Application.get_env(:ecall, __MODULE__)[:access_token]) ->
        {:ok, Application.get_env(:ecall, __MODULE__)[:access_token]}

      true ->
        {:error, :missing_fcm_credentials}
    end
  end

  defp normalize_response({:ok, %Finch.Response{status: status}}) when status in 200..299, do: :ok

  defp normalize_response({:ok, %Finch.Response{status: status, body: body}}) when status in [400, 404] do
    if invalid_token_body?(body), do: {:error, :invalid_token}, else: {:error, {:fcm_rejected, status}}
  end

  defp normalize_response({:ok, %Finch.Response{status: status}}) when status in [401, 403] do
    {:error, {:fcm_auth_error, status}}
  end

  defp normalize_response({:ok, %Finch.Response{status: status}}) when status in [429, 500, 502, 503, 504] do
    {:error, {:fcm_retryable, status}}
  end

  defp normalize_response({:ok, %Finch.Response{status: status}}), do: {:error, {:fcm_unexpected_status, status}}
  defp normalize_response({:error, reason}), do: {:error, reason}

  defp invalid_token_body?(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> invalid_token_error?(decoded)
      {:error, _reason} -> false
    end
  end

  defp invalid_token_error?(%{"error" => %{"details" => details}}) when is_list(details) do
    Enum.any?(details, fn
      %{"errorCode" => "UNREGISTERED"} -> true
      _detail -> false
    end)
  end

  defp invalid_token_error?(%{"error" => %{"status" => "NOT_FOUND"}}), do: true
  defp invalid_token_error?(_decoded), do: false

  defp stringify(map), do: Map.new(map, fn {key, value} -> {to_string(key), to_string(value)} end)
  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
