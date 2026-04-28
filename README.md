# ECall Backend

Phoenix backend for WebRTC signaling, presence, push notifications and messaging.

## Implemented MVP

- Phoenix websocket endpoint and JWT-authenticated user socket.
- Registration/login/refresh/logout API with Argon2 password hashing and refresh-token rotation.
- `user:{id}` channel with Presence, incoming calls and real-time messages.
- `call:{call_id}` channel for call control, SDP and ICE relay.
- PostgreSQL schemas and migrations for calls, messages and device tokens.
- Push notification abstraction with FCM client and dev log client.
- Docker Compose stack with Postgres, Redis, CoTURN, Caddy HTTPS, Prometheus and Grafana.
- REST fallback endpoints and docs in `docs/`.
- Android handoff guide: `docs/android-handoff.md`.

## Quick Start

```bash
mix deps.get
mix ecto.setup
mix phx.server
```

On this machine Elixir is not installed, so use Docker or install Elixir/Mix before running local tests.
