# DevOps

## Local Run

```bash
docker compose up --build
```

Run migrations in the release container:

```bash
docker compose exec app /app/bin/migrate
```

## Ubuntu 22.04 Deployment

One-command install from a clean server:

```bash
curl -fsSL https://raw.githubusercontent.com/vaalimusic/ECall_Backend/main/scripts/install_ubuntu.sh | sudo DOMAIN=ecall.everty.ru bash
```

The script installs Docker, clones the repository into `/opt/ecall-backend`, creates `.env`, starts Docker Compose, runs migrations and uses Caddy to issue HTTPS certificates automatically.

Manual update after changes are pushed:

```bash
cd /opt/ecall-backend
sudo git pull --ff-only
sudo docker compose up -d --build
sudo docker compose exec -T app /app/bin/ecall eval "Ecall.Release.migrate()"
```

## Scaling

- Run multiple `app` replicas behind Caddy or a cloud load balancer.
- Keep sticky sessions enabled for websocket stability.
- Use Erlang distribution or Redis Pub/Sub for cross-node broadcasts before production multi-node rollout.
- Keep Postgres as the source of truth for call history and messages.
- Move FCM access tokens to short-lived Google service account OAuth tokens before production.
