defmodule Ecall.Push.LogClient do
  require Logger

  def deliver(device_token, type, payload) do
    Logger.info("push #{type} user_id=#{device_token.user_id} token=#{device_token.token} payload=#{inspect(payload)}")
    :ok
  end
end
