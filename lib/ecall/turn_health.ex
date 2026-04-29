defmodule Ecall.TurnHealth do
  @stun_binding_request 0x0001
  @stun_binding_success 0x0101
  @magic_cookie 0x2112A442
  @default_timeout_ms 1_500

  def check(opts \\ []) do
    host = Keyword.get(opts, :host, turn_host())
    port = Keyword.get(opts, :port, turn_port())
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    with {:ok, address} <- resolve(host),
         {:ok, socket} <- :gen_udp.open(0, [:binary, active: false]) do
      try do
        transaction_id = :crypto.strong_rand_bytes(12)
        request = stun_request(transaction_id)

        with :ok <- :gen_udp.send(socket, address, port, request) do
          recv_response(socket, transaction_id, timeout)
        end
      after
        :gen_udp.close(socket)
      end
    else
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp recv_response(socket, transaction_id, timeout) do
    case :gen_udp.recv(socket, 0, timeout) do
      {:ok, {_address, _port, <<@stun_binding_success::16, _length::16, @magic_cookie::32, response_transaction_id::binary-size(12), _attrs::binary>>}} ->
        if response_transaction_id == transaction_id do
          :ok
        else
          {:error, :unexpected_stun_transaction}
        end

      {:ok, {_address, _port, _packet}} ->
        {:error, :unexpected_stun_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp stun_request(transaction_id) do
    <<@stun_binding_request::16, 0::16, @magic_cookie::32, transaction_id::binary>>
  end

  defp resolve(host) do
    host
    |> to_charlist()
    |> :inet.getaddr(:inet)
  end

  defp turn_host do
    System.get_env("TURN_HOST") || System.get_env("PHX_HOST") || "localhost"
  end

  defp turn_port do
    "TURN_PORT"
    |> System.get_env("3478")
    |> String.to_integer()
  rescue
    _error -> 3478
  end
end
