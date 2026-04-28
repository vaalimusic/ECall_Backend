defmodule Ecall.Repo do
  use Ecto.Repo,
    otp_app: :ecall,
    adapter: Ecto.Adapters.Postgres
end
