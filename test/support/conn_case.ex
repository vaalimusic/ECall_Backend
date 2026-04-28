defmodule EcallWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint EcallWeb.Endpoint
      use EcallWeb, :verified_routes
      import Plug.Conn
      import Phoenix.ConnTest
      import EcallWeb.ConnCase
    end
  end

  setup tags do
    Ecall.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
