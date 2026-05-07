import Config

parse_integer_env = fn name, default ->
  case System.get_env(name) do
    nil ->
      default

    value ->
      case Integer.parse(value) do
        {integer, ""} when integer > 0 -> integer
        _ -> default
      end
  end
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL is required, for example ecto://USER:PASS@HOST/DATABASE"

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE is required"

  host = System.get_env("PHX_HOST", "ecall.everty.ru")
  port = parse_integer_env.("PORT", 4000)

  config :ecall, Ecall.Repo,
    url: database_url,
    pool_size: parse_integer_env.("POOL_SIZE", 20),
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

  if service_account_json = System.get_env("FCM_SERVICE_ACCOUNT_JSON") do
    config :ecall, Ecall.Goth,
      source:
        {:service_account, Jason.decode!(service_account_json),
         scopes: ["https://www.googleapis.com/auth/firebase.messaging"]}
  end

  config :ecall,
    cluster_min_size: parse_integer_env.("CLUSTER_MIN_SIZE", 1)

  config :ecall, Ecall.Admission,
    max_active_calls: parse_integer_env.("MAX_ACTIVE_CALLS", 10_000),
    max_processes: parse_integer_env.("MAX_BEAM_PROCESSES", 200_000),
    max_run_queue: parse_integer_env.("MAX_BEAM_RUN_QUEUE", 256),
    max_memory_bytes: parse_integer_env.("MAX_BEAM_MEMORY_BYTES", 0),
    call_initiate_interval_ms: parse_integer_env.("CALL_INITIATE_INTERVAL_MS", 1_200)

  config :ecall, Ecall.Calls.ParticipantSweeper,
    stale_after_seconds: parse_integer_env.("CALL_PARTICIPANT_STALE_AFTER_SECONDS", 45),
    interval_ms: parse_integer_env.("CALL_PARTICIPANT_SWEEP_INTERVAL_MS", 15_000)

  if System.get_env("CLUSTER_ENABLED", "false") == "true" do
    cluster_secret =
      System.get_env("CLUSTER_SECRET") ||
        System.get_env("RELEASE_COOKIE") ||
        secret_key_base

    config :libcluster,
      topologies: [
        ecall_gossip: [
          strategy: Cluster.Strategy.Gossip,
          config: [
            secret: cluster_secret
          ]
        ]
      ]
  else
    config :libcluster, topologies: []
  end
end
