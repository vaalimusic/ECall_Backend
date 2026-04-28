defmodule Ecall.AuthTest do
  use Ecall.DataCase, async: true

  alias Ecall.Auth

  test "registers user and returns token pair" do
    assert {:ok, session} =
             Auth.register(%{
               "email" => "User@Example.com",
               "password" => "super-secret",
               "display_name" => "User"
             })

    assert session.user.email == "user@example.com"
    assert is_binary(session.access_token)
    assert is_binary(session.refresh_token)
  end

  test "login and refresh rotate refresh token" do
    assert {:ok, _session} =
             Auth.register(%{
               "email" => "login@example.com",
               "password" => "super-secret"
             })

    assert {:ok, login} =
             Auth.login(%{
               "email" => "login@example.com",
               "password" => "super-secret"
             })

    assert {:ok, refreshed} = Auth.refresh(login.refresh_token)
    assert refreshed.refresh_token != login.refresh_token
    assert {:error, :refresh_token_reuse} = Auth.refresh(login.refresh_token)
  end

  test "logout revokes refresh token" do
    assert {:ok, session} =
             Auth.register(%{
               "email" => "logout@example.com",
               "password" => "super-secret"
             })

    assert :ok = Auth.logout(session.refresh_token)
    assert {:error, :refresh_token_reuse} = Auth.refresh(session.refresh_token)
  end
end
