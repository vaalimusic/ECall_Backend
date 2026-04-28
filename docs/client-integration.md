# Client Integration

## WebSocket Auth

The server expects a JWT access token with `sub=<user_id>`. A Phoenix signed token is also accepted for test tooling. For local load tests only, set `ALLOW_INSECURE_SOCKET_AUTH=true` and pass `user_id` directly.

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
