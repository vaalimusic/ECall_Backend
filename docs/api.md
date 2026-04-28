# API

## WebSocket

Connect with JWT access token:

```text
wss://ecall.everty.ru/socket/websocket?token=<signed-token>&vsn=2.0.0
```

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
- `GET /api/conversations/:user_id/:peer_id/messages?limit=50`
- `POST /api/messages` with `{"from":"1","to":"2","body":"hello"}`
- `GET /api/users/:user_id/calls?limit=50`
- `POST /api/users/:user_id/device_tokens` with `{"token":"...","platform":"ios"}`
- `GET /metrics`
