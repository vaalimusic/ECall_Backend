# API

Base URL:

```text
https://ecall.everty.ru
```

## Auth

`POST /api/auth/register`

```json
{"email":"user@example.com","password":"secret123","display_name":"User"}
```

`POST /api/auth/login`

```json
{"email":"user@example.com","password":"secret123"}
```

Auth response:

```json
{
  "user": {"id":"uuid","email":"user@example.com","phone":null,"display_name":"User"},
  "access_token": "jwt",
  "token_type": "Bearer",
  "expires_at": "2026-05-01T22:00:00Z",
  "refresh_token": "opaque-refresh-token"
}
```

Use REST auth header:

```text
Authorization: Bearer <access_token>
```

Other auth endpoints:

- `POST /api/auth/refresh` with `{"refresh_token":"..."}`
- `POST /api/auth/logout` with `{"refresh_token":"..."}`
- `GET /api/auth/me`

## WebSocket

Connect with raw JWT in the query string:

```text
wss://ecall.everty.ru/socket/websocket?token=<access_token>&vsn=2.0.0
```

Do not put `Bearer ` into the WebSocket query value.

Channels:

- `user:{myUserId}`: global user channel for presence, incoming calls and messages.
- `call:{call_id}`: per-call channel for WebRTC signaling and call controls.

After login, Android must keep `user:{myUserId}` joined globally, not only on a chat or call screen.

## Messaging

Send through WebSocket on `user:{myUserId}`:

```json
{"event":"message:new","payload":{"to":"peerUserId","body":"Hello","client_message_id":"local-uuid"}}
```

Or through REST:

```http
POST /api/messages
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{"to":"peerUserId","body":"Hello","client_message_id":"local-uuid"}
```

The backend stores the message and broadcasts to the recipient:

```text
topic: user:{peerUserId}
event: message:new
```

History:

```text
GET /api/conversations/{myUserId}/{peerUserId}/messages?limit=50
```

Do not call history with the same id twice unless the user is intentionally chatting with self.

Sync after reconnect:

```text
GET /api/users/{myUserId}/messages/sync?since=<last_inserted_at>&limit=200
```

Voice note fallback:

```json
{
  "to": "peerUserId",
  "type": "voice_note",
  "client_message_id": "local-voice-note-id",
  "metadata": {
    "media_url": "https://cdn.example.test/voice/1.ogg",
    "duration_ms": 12000,
    "size_bytes": 48000,
    "sha256": "hex-or-base64-sha256",
    "mime_type": "audio/ogg; codecs=opus"
  }
}
```

## Calls

Start call on `user:{myUserId}`:

```json
{"event":"call:initiate","payload":{"to":"peerUserId","media":"video","client_call_id":"local-call-uuid"}}
```

Incoming call arrives on `user:{peerUserId}`:

```text
event: call:ringing
```

Callee should acknowledge ringing delivery on `user:{calleeId}`:

```json
{"event":"call:ringing_ack","payload":{"call_id":"call-uuid"}}
```

Then both sides join:

```text
call:{call_id}
```

Call channel events:

- `call:accept`
- `call:reject`
- `call:busy`
- `call:end`
- `call:mute`
- `call:unmute`
- `call:video_on`
- `call:video_off`
- `call:switch_camera`
- `call:heartbeat`
- `call:reconnecting`
- `call:reconnected`
- `webrtc:offer`
- `webrtc:answer`
- `webrtc:ice`

ICE candidate payload:

```json
{"candidate":"candidate:...","sdpMid":"0","sdpMLineIndex":0}
```

Call state rules:

- Only callee sends `call:accept`, `call:reject`, `call:busy`.
- Either participant can send `call:end`.
- After `call:end`, `call:reject`, `call:busy` or `call:timeout`, leave `call:{call_id}` and clear active call state.
- Redial uses a new `client_call_id`.

Call recovery:

- `GET /api/users/{myUserId}/calls/active`
- `GET /api/calls/{call_id}`
- `GET /api/users/{myUserId}/calls?limit=50`

## WebRTC ICE Servers

```text
GET /api/webrtc/ice_servers
Authorization: Bearer <access_token>
```

Use returned `data` as `iceServers` for `PeerConnection`.

## Device Tokens

```text
POST /api/users/{myUserId}/device_tokens
```

```json
{"token":"FCM_DEVICE_TOKEN","platform":"android"}
```

## Health

- `GET /api/health`
- `GET /api/health/live`
- `GET /api/health/ready`
- `GET /api/health/turn`
- `GET /metrics`
