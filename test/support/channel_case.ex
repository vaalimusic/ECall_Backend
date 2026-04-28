defmodule EcallWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint EcallWeb.Endpoint
      import Phoenix.ChannelTest
      import EcallWeb.ChannelCase
    end
  end

  setup tags do
    Ecall.DataCase.setup_sandbox(tags)
    :ok
  end
end
