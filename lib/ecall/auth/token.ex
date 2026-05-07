defmodule Ecall.Auth.Token do
  @access_token_ttl_seconds 60 * 60

  def generate(user_id, extra_claims \\ %{}) do
    now = System.os_time(:second)

    claims =
      %{
        "aud" => "ECall",
        "active" => true,
        "exp" => now + @access_token_ttl_seconds,
        "iat" => now,
        "iss" => "ECall",
        "jti" => random_jti(),
        "nbf" => now,
        "sub" => to_string(user_id),
        "typ" => "access"
      }
      |> Map.merge(extra_claims)
      |> Map.merge(%{"sub" => to_string(user_id), "typ" => "access"})

    token =
      %{"alg" => "HS256", "typ" => "JWT"}
      |> encode_segment()
      |> then(fn header -> header <> "." <> encode_segment(claims) end)
      |> sign()

    {:ok, token, claims}
  end

  def verify(token) do
    case verify_with_claims(token) do
      {:ok, user_id, _claims} -> {:ok, user_id}
      {:error, reason} -> {:error, reason}
    end
  end

  def verify_with_claims(token) do
    with {:ok, claims} <- verify_claims(token),
         :ok <- validate_claims(claims),
         %{"sub" => user_id} when is_binary(user_id) <- claims do
      {:ok, user_id, claims}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_subject}
    end
  end

  defp verify_claims(token) when is_binary(token) do
    with [header_segment, payload_segment, signature_segment] <- String.split(token, ".", parts: 3),
         {:ok, %{"alg" => "HS256"}} <- decode_segment(header_segment),
         {:ok, claims} <- decode_segment(payload_segment),
         true <- valid_signature?(header_segment <> "." <> payload_segment, signature_segment) do
      {:ok, claims}
    else
      false -> {:error, :invalid_signature}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_token}
    end
  end

  defp secret do
    configured_secret = Application.get_env(:ecall, __MODULE__, [])[:secret]

    configured_secret
    |> blank_to_nil()
    |> Kernel.||(blank_to_nil(System.get_env("JWT_SECRET")))
    |> Kernel.||("dev-jwt-secret-change-me")
  end

  defp validate_claims(%{"exp" => exp, "nbf" => nbf, "typ" => "access"} = claims) do
    now = System.os_time(:second)

    cond do
      not is_integer(exp) or exp <= now -> {:error, :token_expired}
      is_integer(nbf) and nbf > now -> {:error, :token_not_yet_valid}
      Map.get(claims, "active") != true -> {:error, :user_disabled}
      true -> :ok
    end
  end

  defp validate_claims(%{"typ" => _other}), do: {:error, :invalid_token_type}
  defp validate_claims(_claims), do: {:error, :invalid_claims}

  defp sign(signing_input) do
    signing_input <> "." <> signature(signing_input)
  end

  defp valid_signature?(signing_input, signature_segment) do
    expected = signature(signing_input)
    byte_size(expected) == byte_size(signature_segment) and Plug.Crypto.secure_compare(expected, signature_segment)
  end

  defp signature(signing_input) do
    :hmac
    |> :crypto.mac(:sha256, secret(), signing_input)
    |> Base.url_encode64(padding: false)
  end

  defp encode_segment(data) do
    data
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  defp decode_segment(segment) do
    with {:ok, json} <- Base.url_decode64(segment, padding: false),
         {:ok, data} <- Jason.decode(json) do
      {:ok, data}
    else
      :error -> {:error, :invalid_base64}
      {:error, _reason} -> {:error, :invalid_json}
    end
  end

  defp random_jti do
    18
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
