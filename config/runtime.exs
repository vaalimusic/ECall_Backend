import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL is required, for example ecto://USER:PASS@HOST/DATABASE"

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE is required"

  host = System.get_env("PHX_HOST", "ecall.everty.ru")
  port = String.to_integer(System.get_env("PORT", "4000"))

  config :ecall, Ecall.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "20")),
    ssl: System.get_env("ECTO_SSL", "false") == "true"

  config :ecall, EcallWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base,
    check_origin: [
      "https://#{host}",
      "wss://#{host}"
    ]

  config :ecall, Ecall.Auth.Token,
    secret: System.get_env("JWT_SECRET") || secret_key_base

  config :ecall, Ecall.Push.FcmClient,
    adapter: Ecall.Push.FcmClient,
    project_id: System.get_env("FCM_PROJECT_ID"),
    access_token: System.get_env("FCM_ACCESS_TOKEN")
end
