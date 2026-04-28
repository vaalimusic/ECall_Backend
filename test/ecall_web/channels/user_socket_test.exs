defmodule EcallWeb.UserSocketTest do
  use EcallWeb.ChannelCase, async: true

  alias EcallWeb.UserSocket

  test "connects with signed token" do
    token = Phoenix.Token.sign(EcallWeb.Endpoint, "user auth", "42")
    assert {:ok, socket} = connect(UserSocket, %{"token" => token})
    assert socket.assigns.user_id == "42"
  end

  test "connects with jwt token" do
    assert {:ok, token, _claims} = Ecall.Auth.Token.generate("42")
    assert {:ok, socket} = connect(UserSocket, %{"token" => token})
    assert socket.assigns.user_id == "42"
  end

  test "connects with bearer jwt token" do
    assert {:ok, token, _claims} = Ecall.Auth.Token.generate("42")
    assert {:ok, socket} = connect(UserSocket, %{"token" => "Bearer #{token}"})
    assert socket.assigns.user_id == "42"
  end

  test "connects with access_token query param" do
    assert {:ok, token, _claims} = Ecall.Auth.Token.generate("42")
    assert {:ok, socket} = connect(UserSocket, %{"access_token" => token})
    assert socket.assigns.user_id == "42"
  end
end
