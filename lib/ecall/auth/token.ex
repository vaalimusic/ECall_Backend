defmodule Ecall.Auth.Token do
  use Joken.Config

  @impl true
  def token_config do
    default_claims(default_exp: 60 * 60)
    |> add_claim("sub", fn -> nil end, &is_binary/1)
  end

  def generate(user_id, extra_claims \\ %{}) do
    claims = Map.merge(extra_claims, %{"sub" => to_string(user_id)})
    generate_and_sign(claims, signer())
  end

  def verify(token) do
    case verify_and_validate(token, signer()) do
      {:ok, %{"sub" => user_id}} -> {:ok, user_id}
      {:error, reason} -> {:error, reason}
    end
  end

  defp signer do
    Joken.Signer.create("HS256", secret())
  end

  defp secret do
    Application.get_env(:ecall, __MODULE__, [])[:secret] ||
      System.get_env("JWT_SECRET") ||
      "dev-jwt-secret-change-me"
  end
end
