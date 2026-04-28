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
- Keep sticky sessions enabled for websocket stability.
- Use Erlang distribution or Redis Pub/Sub for cross-node broadcasts before production multi-node rollout.
- Keep Postgres as the source of truth for call history and messages.
- Move FCM access tokens to short-lived Google service account OAuth tokens before production.
