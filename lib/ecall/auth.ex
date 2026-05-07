defmodule Ecall.Auth do
  import Ecto.Query

  alias Ecall.Auth.{RefreshToken, Token, User}
  alias Ecall.Repo

  @refresh_token_days 30

  def register(attrs, meta \\ %{}) do
    Repo.transaction(fn ->
      case %User{}
           |> User.registration_changeset(attrs)
           |> Repo.insert() do
        {:ok, user} -> issue_session!(user, meta)
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def login(attrs, meta \\ %{})

  def login(%{"email" => email, "password" => password}, meta) do
    user = get_user_by_email(email)

    cond do
      is_nil(user) ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}

      user.disabled_at ->
        {:error, :user_disabled}

      Argon2.verify_pass(password, user.password_hash) ->
        issue_session(user, meta)

      true ->
        {:error, :invalid_credentials}
    end
  end

  def login(_attrs, _meta), do: {:error, :invalid_credentials}

  def refresh(refresh_token, meta \\ %{}) when is_binary(refresh_token) do
    token_hash = hash_token(refresh_token)
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      token =
        RefreshToken
        |> where([t], t.token_hash == ^token_hash)
        |> lock("FOR UPDATE")
        |> Repo.one()

      token = if token, do: Repo.preload(token, :user)

      cond do
        is_nil(token) ->
          Repo.rollback(:invalid_refresh_token)

        token.revoked_at != nil ->
          revoke_all_user_tokens(token.user_id)
          Repo.rollback(:refresh_token_reuse)

        DateTime.compare(token.expires_at, now) != :gt ->
          Repo.rollback(:refresh_token_expired)

        token.user.disabled_at != nil ->
          Repo.rollback(:user_disabled)

        true ->
          new_session = issue_session!(token.user, meta)

          token
          |> RefreshToken.changeset(%{
            revoked_at: now,
            replaced_by_token_id: new_session.refresh_token_id
          })
          |> Repo.update!()

          new_session
      end
    end)
  end

  def logout(refresh_token) when is_binary(refresh_token) do
    RefreshToken
    |> where([t], t.token_hash == ^hash_token(refresh_token) and is_nil(t.revoked_at))
    |> Repo.update_all(set: [revoked_at: DateTime.utc_now()])

    :ok
  end

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) when is_binary(email) do
    normalized =
      email
      |> String.trim()
      |> String.downcase()

    Repo.get_by(User, email: normalized)
  end

  def issue_session(user, meta \\ %{}) do
    Repo.transaction(fn ->
      issue_session!(user, meta)
    end)
  end

  def issue_session!(%User{} = user, meta \\ %{}) do
    {:ok, access_token, claims} =
      Token.generate(user.id, %{
        "typ" => "access",
        "email" => user.email,
        "phone" => user.phone,
        "display_name" => user.display_name,
        "active" => is_nil(user.disabled_at)
      })

    raw_refresh_token = generate_refresh_token()

    refresh_token =
      %RefreshToken{}
      |> RefreshToken.changeset(%{
        user_id: user.id,
        token_hash: hash_token(raw_refresh_token),
        expires_at: DateTime.add(DateTime.utc_now(), @refresh_token_days, :day),
        user_agent: meta[:user_agent],
        ip_address: meta[:ip_address]
      })
      |> Repo.insert!()

    %{
      user: public_user(user),
      access_token: access_token,
      access_token_expires_at: DateTime.from_unix!(claims["exp"]),
      refresh_token: raw_refresh_token,
      refresh_token_id: refresh_token.id
    }
  end

  def public_user(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      phone: user.phone,
      display_name: user.display_name
    }
  end

  defp generate_refresh_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp hash_token(token) do
    :crypto.hash(:sha256, token)
    |> Base.encode16(case: :lower)
  end

  defp revoke_all_user_tokens(user_id) do
    RefreshToken
    |> where([t], t.user_id == ^user_id and is_nil(t.revoked_at))
    |> Repo.update_all(set: [revoked_at: DateTime.utc_now()])
  end
end
