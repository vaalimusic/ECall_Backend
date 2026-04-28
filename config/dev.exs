import Config

config :ecall, Ecall.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", "ecall_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :ecall, EcallWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: String.duplicate("dev", 32),
  watchers: []

config :ecall, Ecall.Push.FcmClient, adapter: Ecall.Push.LogClient
config :ecall, EcallWeb.RateLimitPlug, scale_ms: 60_000, limit: 300
