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

1. Install Docker and Docker Compose.
2. Copy `.env.example` to `.env` and set real secrets.
3. Point DNS for `ecall.everty.ru` to the server.
4. Replace the Nginx HTTP-only config with a Let's Encrypt TLS config or terminate TLS before Nginx.
5. Run `docker compose up -d --build`.

## Scaling

- Run multiple `app` replicas behind Nginx or a cloud load balancer.
- Keep sticky sessions enabled for websocket stability.
- Use Erlang distribution or Redis Pub/Sub for cross-node broadcasts before production multi-node rollout.
- Keep Postgres as the source of truth for call history and messages.
- Move FCM access tokens to short-lived Google service account OAuth tokens before production.
