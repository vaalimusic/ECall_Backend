defmodule EcallWeb.ParamHelpers do
  def parse_limit(params, opts \\ []) do
    default = Keyword.get(opts, :default, 50)
    max = Keyword.get(opts, :max, 200)

    params
    |> Map.get("limit", Integer.to_string(default))
    |> parse_positive_integer(max)
  end

  defp parse_positive_integer(value, max) when is_binary(value) do
    case Integer.parse(value) do
      {limit, ""} when limit > 0 -> {:ok, min(limit, max)}
      _ -> {:error, :invalid_limit}
    end
  end

  defp parse_positive_integer(_value, _max), do: {:error, :invalid_limit}
end
