# API

## WebSocket

Connect with JWT access token:

```text
wss://ecall.everty.ru/socket/websocket?token=<JWT_ACCESS_TOKEN>&vsn=2.0.0
```

Use the raw JWT in `token`. REST uses `Authorization: Bearer <JWT_ACCESS_TOKEN>`, but the WebSocket query value should not include the `Bearer ` prefix.

Channels:

- `user:{id}`: user presence, incoming calls, messages.
- `call:{call_id}`: WebRTC signaling and call controls.

### User Events

`call:initiate`

```json
{"to":"user_2","media":"video"}
```

`message:new`

```json
{"to":"user_2","body":"Hello"}
```

`message:delivered`

```json
{"message_id":"uuid"}
```

`message:read`

```json
{"message_id":"uuid"}
```

### Call Events

- `call:accept`
- `call:reject`
- `call:busy`
- `call:end`
- `call:mute`
- `call:unmute`
- `call:video_on`
- `call:video_off`
- `call:switch_camera`
- `webrtc:offer`
- `webrtc:answer`
- `webrtc:ice`

Example ICE payload:

```json
{"candidate":"candidate:...","sdpMid":"0","sdpMLineIndex":0}
```

## REST

- `GET /api/health`
- `POST /api/auth/register` with `{"email":"user@example.com","password":"secret123","display_name":"User"}`
- `POST /api/auth/login` with `{"email":"user@example.com","password":"secret123"}`
- `POST /api/auth/refresh` with `{"refresh_token":"..."}`
- `POST /api/auth/logout` with `{"refresh_token":"..."}`
- `GET /api/auth/me`
- `GET /api/conversations/:user_id/:peer_id/messages?limit=50`
- `POST /api/messages` with `{"to":"2","body":"hello"}`
- `GET /api/users/:user_id/calls?limit=50`
- `POST /api/users/:user_id/device_tokens` with `{"token":"...","platform":"ios"}`
- `GET /metrics`

All endpoints except `health`, `metrics`, `auth/register`, `auth/login`, `auth/refresh` and `auth/logout` require:

```text
Authorization: Bearer <JWT_ACCESS_TOKEN>
```

`POST /api/messages` stores the message and broadcasts `message:new` to `user:{recipient_id}` when the recipient is online.

Auth response:

```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "phone": null,
    "display_name": "User"
  },
  "access_token": "jwt",
  "token_type": "Bearer",
  "expires_at": "2026-04-28T22:00:00Z",
  "refresh_token": "opaque-refresh-token"
}
```
