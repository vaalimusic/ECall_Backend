# DevOps

## Local Run

```bash
docker compose up --build
```

Run migrations in the release container:

```bash
docker compose exec app /app/bin/migrate
```

## Health Checks

Basic process liveness:

```bash
curl -fsS http://localhost/api/health/live
```

Readiness for traffic:

```bash
curl -fsS http://localhost/api/health/ready
```

`/api/health/ready` checks Postgres, Phoenix PubSub and the endpoint process. Docker uses this endpoint as the `app` container healthcheck.

TURN/STUN reachability:

```bash
curl -fsS http://localhost/api/health/turn
```

`/api/health/turn` sends a STUN binding request to `TURN_HOST:TURN_PORT`. It is intentionally separate from readiness so the app does not restart-loop when TURN has a network incident.

## Admission Control

New call setup is protected by BEAM-level admission control. Tune these environment variables before a large event:

- `MAX_ACTIVE_CALLS`: maximum active calls accepted by one deployment before new `call:initiate` requests return `server_overloaded`.
- `MAX_BEAM_PROCESSES`: maximum Erlang process count before new calls are rejected.
- `MAX_BEAM_RUN_QUEUE`: maximum Erlang run queue before new calls are rejected.
- `MAX_BEAM_MEMORY_BYTES`: optional total BEAM memory ceiling; `0` disables this limit.
- `CALL_INITIATE_INTERVAL_MS`: per-caller minimum interval for new call setup. Idempotent retries for an existing `client_call_id` still return the existing call.
- `CALL_PARTICIPANT_STALE_AFTER_SECONDS`: how long a joined call participant may go without heartbeat before being marked stale.
- `CALL_PARTICIPANT_SWEEP_INTERVAL_MS`: how often stale call participants are cleaned.

Existing calls should be protected before new calls are admitted. Alert on `ecall_call_admission_rejected_total`, `ecall_call_rate_limited_total`, `ecall_beam_run_queue`, `ecall_beam_process_count` and `ecall_beam_total_memory_bytes`.

## Failure Checks

Before a production rollout, verify these behaviors:

- `mix deps.get`, `mix format --check-formatted`, `mix test` and `docker build .` pass;
- `server_overloaded` is returned when admission limits are intentionally lowered in staging;
- invalid REST `limit` params return `400`, not `500`;
- migrations run cleanly against a copy of production data;
- `/api/health/ready` returns `cluster.size >= CLUSTER_MIN_SIZE` during multi-replica operation;
- `/api/health/turn` returns `200` while CoTURN is reachable;
- `ecall_push_retry_pending_count` does not grow continuously;
- two app replicas do not duplicate push retry delivery;
- app restart during a ringing call eventually produces `call:timeout`;
- reconnecting clients call active-call restore and message sync before creating new state.

## Backups

Create a compressed Postgres backup:

```bash
scripts/backup_postgres.sh
```

Backups are written to `backups/postgres` by default and kept for 7 days. Override with:

```bash
BACKUP_DIR=/secure/ecall-backups RETENTION_DAYS=30 scripts/backup_postgres.sh
```

Test restore on a non-production copy before trusting backups:

```bash
scripts/restore_postgres.sh /secure/ecall-backups/ecall_ecall_prod_YYYYMMDDTHHMMSSZ.dump
```

## Push Delivery

FCM delivery outcomes are exposed in `/metrics`. The endpoint requires Basic Auth inside the Phoenix app and is also blocked from the public Caddy vhost:

- `ecall_push_delivered_total`
- `ecall_push_failed_total`
- `ecall_push_invalid_token_total`
- `ecall_push_retry_delivered_total`
- `ecall_push_retry_failed_total`
- `ecall_push_retry_pending_count`

Invalid FCM tokens are deleted automatically. Retryable FCM failures are stored in `push_jobs` and retried by `Ecall.Push.RetryWorker` with backoff. Alert if `ecall_push_retry_pending_count` grows for more than a few minutes.

Use `FCM_SERVICE_ACCOUNT_JSON` for production Firebase Cloud Messaging. When it is set, the backend fetches short-lived OAuth access tokens with Goth. `FCM_ACCESS_TOKEN` remains only as a fallback for temporary manual testing.

## Ubuntu 22.04 Deployment

One-command install from a clean server:

```bash
curl -fsSL https://raw.githubusercontent.com/vaalimusic/ECall_Backend/main/scripts/install_ubuntu.sh | sudo DOMAIN=ecall.everty.ru bash
```

The script installs Docker, clones the repository into `/opt/ecall-backend`, creates `.env`, starts Docker Compose, runs migrations and uses Caddy to issue HTTPS certificates automatically.

If Caddy logs show DNS errors for Let's Encrypt, Docker is probably passing `127.0.0.53` into containers. The compose file pins public DNS resolvers for `app`, `caddy` and `prometheus`.

If Caddy logs show `network is unreachable` from inside the container, enable Docker forwarding on the server:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo net.ipv4.ip_forward=1 | sudo tee /etc/sysctl.d/99-ecall-docker-forward.conf
sudo ufw default allow routed
sudo iptables -P FORWARD ACCEPT
sudo systemctl restart docker
cd /opt/ecall-backend
sudo docker compose down --remove-orphans
sudo docker compose up -d --remove-orphans
```

Manual update after changes are pushed:

```bash
cd /opt/ecall-backend
sudo git pull --ff-only
sudo docker compose up -d --build
sudo docker compose exec -T app /app/bin/ecall eval "Ecall.Release.migrate()"
```

## Scaling

- Run multiple `app` replicas behind Caddy or a cloud load balancer.
- Enable Erlang clustering for cross-node Phoenix PubSub and Presence:

```bash
CLUSTER_ENABLED=true
CLUSTER_MIN_SIZE=2
docker compose up -d --build --scale app=2
```

- Keep the same `RELEASE_COOKIE` and `CLUSTER_SECRET` across all app replicas.
- Keep `app` unbound from host ports; Caddy is the public entry point and reverse proxies to `app:4000`.
- Keep sticky sessions enabled for websocket stability.
- Use `/api/health/ready` to confirm `cluster.size` is at least `CLUSTER_MIN_SIZE`.
- Keep Postgres as the source of truth for call history and messages.
- Move FCM access tokens to short-lived Google service account OAuth tokens before production.

See `docs/resilience-plan.md` for the full hardening plan.
