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
{"to":"user_2","media":"video","client_call_id":"local-call-uuid-or-ulid"}
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
- `call:reconnecting`
- `call:reconnected`
- `call:heartbeat`
- `webrtc:offer`
- `webrtc:answer`
- `webrtc:ice`

Example ICE payload:

```json
{"candidate":"candidate:...","sdpMid":"0","sdpMLineIndex":0}
```

Call state rules:

- `call:accept`, `call:reject` and `call:busy` are valid only while the call is `ringing`.
- Only the callee can send `call:accept`, `call:reject` or `call:busy`.
- Either participant can send `call:end` while the call is `ringing` or `accepted`.
- Terminal calls cannot be accepted or ended again.
- After `ended`, `rejected`, `busy` or `missed`, redial with a new `client_call_id`; reusing the old `client_call_id` returns the original call.

## REST

- `GET /api/health`
- `GET /api/health/live`
- `GET /api/health/ready`
- `GET /api/health/turn`
- `POST /api/auth/register` with `{"email":"user@example.com","password":"secret123","display_name":"User"}`
- `POST /api/auth/login` with `{"email":"user@example.com","password":"secret123"}`
- `POST /api/auth/refresh` with `{"refresh_token":"..."}`
- `POST /api/auth/logout` with `{"refresh_token":"..."}`
- `GET /api/auth/me`
- `GET /api/conversations/:user_id/:peer_id/messages?limit=50`
- `POST /api/messages` with `{"to":"2","body":"hello","client_message_id":"local-uuid-or-ulid"}`
- `GET /api/calls/:id`
- `GET /api/users/:user_id/calls/active`
- `GET /api/users/:user_id/messages/sync?since=2026-04-30T00:00:00Z&limit=200`
- `GET /api/users/:user_id/calls?limit=50`
- `POST /api/users/:user_id/device_tokens` with `{"token":"...","platform":"ios"}`
- `GET /api/webrtc/ice_servers`
- `GET /metrics`

All endpoints except `health`, `metrics`, `auth/register`, `auth/login`, `auth/refresh` and `auth/logout` require:

```text
Authorization: Bearer <JWT_ACCESS_TOKEN>
```

`POST /api/messages` stores the message and broadcasts `message:new` to `user:{recipient_id}` when the recipient is online.

`client_call_id` is optional for legacy clients but recommended. Reusing the same `client_call_id` for the same caller returns the original call and prevents duplicate call setup after client retries.

`call:initiate` can return `server_overloaded` when admission control decides that accepting a new call would risk already active calls. Clients must back off instead of retrying immediately.

`call:initiate` can return `rate_limited` when the same caller starts new calls too quickly. This protects the system from retry storms during poor network conditions.

`call:initiate` can return `callee_busy` when the callee already has an active ringing or accepted call, or `caller_has_active_call` when the caller already has an active call.

After receiving `call:ringing`, the callee should push `call:ringing_ack` on `user:{id}` with `{"call_id":"..."}`. The server broadcasts `call:ringing_ack` to both users to confirm device-level delivery.

After joining `call:{call_id}`, clients should push `call:heartbeat` every 10-15 seconds. The server records participant `last_seen_at` in Postgres.

`client_message_id` is optional for legacy clients but recommended. Reusing the same `client_message_id` for the same sender returns the original message and prevents duplicate sends after client retries.

`message:new` also accepts `voice_note` fallback messages:

```json
{
  "to": "2",
  "type": "voice_note",
  "client_message_id": "local-voice-note-uuid-or-ulid",
  "metadata": {
    "media_url": "https://cdn.example.test/voice/1.ogg",
    "duration_ms": 12000,
    "size_bytes": 48000,
    "sha256": "hex-or-base64-sha256",
    "mime_type": "audio/ogg; codecs=opus"
  }
}
```

Voice note metadata is bounded: `duration_ms` must be 1-120000 and `size_bytes` must be 1-2000000.

`GET /api/webrtc/ice_servers` returns STUN/TURN configuration for WebRTC clients:

```json
{
  "data": [
    {"urls": "stun:ecall.everty.ru:3478"},
    {
      "urls": ["turn:ecall.everty.ru:3478?transport=udp", "turn:ecall.everty.ru:3478?transport=tcp"],
      "username": "ecall",
      "credential": "turn-password"
    }
  ]
}
```

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
