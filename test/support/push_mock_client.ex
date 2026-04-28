defmodule Ecall.Push.MockClient do
  def deliver(_device_token, _type, _payload), do: :ok
end
