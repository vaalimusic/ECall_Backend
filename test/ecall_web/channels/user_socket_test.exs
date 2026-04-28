defmodule EcallWeb.UserSocketTest do
  use EcallWeb.ChannelCase, async: true

  alias EcallWeb.UserSocket

  test "connects with signed token" do
    token = Phoenix.Token.sign(EcallWeb.Endpoint, "user auth", "42")
    assert {:ok, socket} = connect(UserSocket, %{"token" => token})
    assert socket.assigns.user_id == "42"
  end
end
