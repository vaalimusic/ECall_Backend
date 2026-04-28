defmodule EcallWeb.ChangesetJSON do
  def errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts
        |> Enum.find_value(key, fn {opt_key, value} ->
          if to_string(opt_key) == key, do: value
        end)
        |> to_string()
      end)
    end)
  end
end
