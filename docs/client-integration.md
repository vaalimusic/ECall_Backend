# Client Integration

## WebSocket Auth

Register or login first:

```http
POST /api/auth/login
Content-Type: application/json
```

```json
{"email":"user@example.com","password":"secret123"}
```

Use the returned `access_token` for REST and WebSocket. The JWT contains `sub=<user_id>` and expires after 1 hour. Use `refresh_token` with `/api/auth/refresh` to rotate and receive a new token pair.

A Phoenix signed token is also accepted for test tooling. For local load tests only, set `ALLOW_INSECURE_SOCKET_AUTH=true` and pass `user_id` directly.

## WebRTC Flow

1. Join `user:{id}`.
2. Start a call with `call:initiate`.
3. Join `call:{call_id}` from the response or incoming `call:ringing`.
4. Caller sends `webrtc:offer`.
5. Callee sends `webrtc:answer`.
6. Both sides forward ICE candidates through `webrtc:ice`.
7. Finish with `call:end`.

The backend does not terminate media. It relays signaling only; browsers or mobile SDKs send media P2P through STUN/TURN.

## Example SDP

```json
{
  "sdp": "v=0\r\no=- 461173305 2 IN IP4 127.0.0.1\r\n...",
  "type": "offer"
}
```
