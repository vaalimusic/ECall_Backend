# Resilience Plan

This is a living plan for turning ECall from an MVP into a failure-tolerant communication system.

Last updated: 2026-04-30

Approximate progress: 97%.

## Goal

Keep private 1:1 communication available during infrastructure failures, deploys, restarts and network disruption. The backend must fail predictably, recover quickly and make client reconnect behavior explicit.

## Current State

- Phoenix backend with JWT auth, refresh tokens, WebSocket signaling, messaging and call history.
- PostgreSQL stores users, refresh tokens, calls, messages and device tokens.
- Docker Compose runs app, Postgres, Redis, CoTURN, Caddy, Prometheus and Grafana.
- CoTURN is available for WebRTC relay.
- CI runs format and tests on GitHub Actions.

## Main Risks

- One `app` container is a single point of failure.
- Active call state and call timeout timers live in `Ecall.Calls.Registry`, so they are lost on restart.
- Phoenix PubSub and Presence can use optional Erlang clustering, but the HA deployment still needs real multi-replica verification.
- `/api/health` only proves that the HTTP process responded, not that dependencies are usable.
- Metrics now cover basic call outcomes, signaling errors, message sync volume and push outcomes. TURN has an explicit health endpoint; socket counts and database latency metrics are still pending.
- Postgres uses one local Docker volume without documented backup and restore verification.

## Predicted Failure Modes

- Bad query params: REST endpoints must return `400` instead of raising. Started: message/call limits and message sync cursors are validated.
- Oversized signaling payloads: WebRTC SDP and ICE candidate payloads are bounded before relay.
- Bad runtime env: integer env vars must fall back safely instead of crashing boot. Started: production runtime parsing clamps key numeric env vars.
- Socket auth failure: counted through `ecall_websocket_auth_rejected_total`.
- Channel join failure: counted through `ecall_channel_join_forbidden_total`.
- Duplicate active calls: database unique index prevents active duplicates per user pair and media type.
- Duplicate call initiate after retry: `client_call_id` idempotency returns the existing call for the same caller.
- Overload during call spike: Erlang admission control rejects new call setup before VM process, run queue, memory or active-call limits threaten existing calls.
- Retry storm from one caller: Erlang ETS gate rate-limits new `call:initiate` attempts per caller while allowing idempotent retries for already created calls.
- Simultaneous calls to a busy user: backend rejects new call setup with `callee_busy` or `caller_has_active_call` while preserving the existing active call.
- Caller cannot tell whether ringing reached the device: callee sends `call:ringing_ack`, and backend broadcasts it to both users.
- App restart or multi-replica routing loses in-memory call participants: `call_participants` stores joins, leaves and heartbeats in Postgres.
- Client disappears without leaving `call:{id}`: participant sweeper marks stale participants left after missed heartbeats.
- Duplicate messages after retry: `client_message_id` idempotency prevents duplicate message rows for the same sender.
- App restart during ringing: database timeout worker marks overdue ringing calls as missed.
- Multi-replica push retry race: push jobs use `FOR UPDATE SKIP LOCKED`.
- TURN outage: `/api/health/turn` detects STUN reachability failure.
- FCM temporary outage: push jobs persist and retry with backoff.
- FCM invalid token: invalid device token is removed.
- Client reconnect during call: client must restore active call state before sending a new `call:initiate`.
- Network change during call: client should use `call:reconnecting`, active-call restore and WebRTC ICE restart instead of ending the call.
- Client reconnect during messaging: client must sync missed messages and apply by message `id`.
- Live media impossible on very poor internet: client can fall back to idempotent `voice_note` messages with bounded metadata.
- Postgres loss: backups exist, but restore drill is still required before production confidence.

## Current Verification Blockers

- `mix` is not installed in the current local environment, so format, compile and tests have not been run locally.
- Docker daemon is unavailable in the current local environment, so release build and multi-replica smoke tests have not been run locally.
- `libcluster` was added to `mix.exs`; `mix deps.get` must generate or update `mix.lock` before a reproducible release.
- Database migrations must be tested on a copy of production data before rollout, especially the active-call uniqueness migration.
- Push retry worker uses database locks; it must be tested with at least two app replicas to confirm there is no duplicate delivery under load.

## Phase 1: Immediate Hardening

- Add separate liveness and readiness endpoints. Done.
- Make readiness check Postgres connectivity. Done.
- Add Docker restart policies and app healthcheck. Done.
- Document operational health commands. Done.
- Add a Postgres backup and restore drill. Started.
- Restrict public access to metrics in production. Done: Caddy blocks public `/metrics`, Phoenix requires Basic Auth, and Prometheus scrapes `app:4000` with credentials internally.
- Add a Docker-based local test path for machines without Elixir installed.

## Phase 2: Multi-Instance Readiness

- Move active call runtime state out of a single GenServer into durable/shared storage. Started: participant joins, leaves, heartbeats and stale cleanup are stored in `call_participants`.
- Replace process-only ringing timers with a restart-safe timeout mechanism based on database state. Done for ringing timeout recovery; active participant state still needs external storage.
- Add Redis PubSub, Postgres PubSub, or Erlang clustering for cross-node broadcasts. Started: optional libcluster gossip is wired for Erlang distributed nodes.
- Run at least two backend replicas behind a load balancer. Started: `app` no longer publishes a host port, so Caddy can front multiple replicas.
- Keep sticky WebSocket sessions until signaling state is fully externalized.
- Add idempotency keys for `call:initiate` and message send requests. Done: calls use `client_call_id`, messages use `client_message_id`, and active-call uniqueness remains as a second guard.

## Phase 3: Communication Reliability

- Publish authenticated ICE server configuration through an API endpoint. Done.
- Harden CoTURN with production credentials, TLS listener and monitoring. Started: `/api/health/turn` validates STUN binding reachability.
- Add reconnect recovery rules for active calls. Done: clients can fetch the active call after reconnect and must not create a new call during recovery.
- Add explicit ringing delivery acknowledgement. Done: `call:ringing_ack` confirms the incoming call reached the callee app.
- Add missed-message sync after WebSocket reconnect. Done.
- Add non-live voice fallback for poor connectivity. Started: `voice_note` message metadata is supported and idempotent.
- Add retry/error handling for FCM delivery and remove invalid device tokens. Done: FCM responses are normalized, invalid tokens are removed, retryable failures are stored in durable `push_jobs`, and a worker retries them with backoff.

## Phase 4: Observability and Runbooks

- Track active sockets, active calls, call setup latency, call failures, message delivery and push failures. Started: basic call outcome, signaling error, message sync, push outcome and push retry counters are exposed.
- Protect active calls during spikes with admission control. Started: `ecall_admission.erl` checks BEAM VM pressure and active-call limits before accepting new calls.
- Protect call setup from retry storms. Started: `ecall_gate.erl` rate-limits new call attempts per caller.
- Add alerts for app down, readiness failure, Postgres failure, high 5xx rate, high call failure rate, TURN failure, disk pressure and certificate expiry.
- Emit structured logs with `request_id`, `user_id` and `call_id`.
- Keep runbooks for deploy, rollback, database restore, certificate renewal, TURN debugging and client signaling checks.

## Commitment

This document should be updated after every resilience-related change. The priority is simple: make it more likely that people can still hear each other when ordinary systems around them stop working.
