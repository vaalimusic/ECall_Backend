# Android Handoff

## What Android Needs

- API base URL: `https://ecall.everty.ru`
- WebSocket URL: `wss://ecall.everty.ru/socket/websocket?token=<access_token>&vsn=2.0.0`
- Auth endpoints from `docs/api.md`
- WebRTC events from `docs/api.md`
- TURN settings from the backend owner, without sharing backend secrets.

## Auth Flow

1. Register:

```http
POST /api/auth/register
```

```json
{"email":"user@example.com","password":"secret123","display_name":"User"}
```

2. Login:

```http
POST /api/auth/login
```

```json
{"email":"user@example.com","password":"secret123"}
```

3. Store the response securely:

```json
{
  "user": {"id":"uuid","email":"user@example.com","phone":null,"display_name":"User"},
  "access_token": "jwt",
  "token_type": "Bearer",
  "expires_at": "2026-04-28T22:00:00Z",
  "refresh_token": "opaque-refresh-token"
}
```

4. Use `Authorization: Bearer <access_token>` for REST.
5. Use the same raw `access_token` in the WebSocket URL query param. Do not put `Bearer ` in the query value.
6. Before or after expiry, call `/api/auth/refresh` with `refresh_token`. Replace both old tokens with the new pair.
7. On logout, call `/api/auth/logout` and delete local tokens.

## WebSocket Flow

1. Connect socket.
2. Join `user:{user.id}`.
3. Start call with `call:initiate`.
4. Join `call:{call_id}`.
5. Relay `webrtc:offer`, `webrtc:answer`, `webrtc:ice`.
6. End with `call:end`.

## Do Not Share With Android

- `POSTGRES_PASSWORD`
- `SECRET_KEY_BASE`
- `JWT_SECRET`
- `TURN_PASSWORD`
- `FCM_ACCESS_TOKEN`
