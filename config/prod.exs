import Config

config :ecall, EcallWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  server: true

config :logger, level: :info
