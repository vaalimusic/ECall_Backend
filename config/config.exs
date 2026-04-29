import Config

config :ecall,
  ecto_repos: [Ecall.Repo],
  generators: [timestamp_type: :utc_datetime_usec],
  cluster_min_size: 1

config :ecall, EcallWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: EcallWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Ecall.PubSub,
  live_view: [signing_salt: "replace-in-prod"]

config :ecall, EcallWeb.Presence,
  pubsub_server: Ecall.PubSub

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :call_id]

config :phoenix, :json_library, Jason

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

import_config "#{config_env()}.exs"
