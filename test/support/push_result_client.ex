defmodule Ecall.Push.ResultClient do
  def deliver(device_token, _type, _payload) do
    case device_token.token do
      "invalid" -> {:error, :invalid_token}
      "failed" -> {:error, :temporary_failure}
      _token -> :ok
    end
  end
end
