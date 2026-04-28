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

For WebSocket, pass the raw token in query params:

```text
wss://ecall.everty.ru/socket/websocket?token=<access_token>&vsn=2.0.0
```

Do not prefix the query value with `Bearer `. `Authorization: Bearer <access_token>` is for REST requests. The backend also accepts `access_token=<token>` and will tolerate `Bearer <token>` during socket auth, but raw `token=<access_token>` is the primary contract.

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

The client must join only the current `call:{call_id}` once per call screen. Repeated joins to many different `call_id` values usually mean the app is repeatedly calling `call:initiate` or recreating the call screen/socket subscription. The backend reuses an active call for the same two users, but the client should still debounce the call button and leave the channel after `call:end`.

## Messaging Flow

After login, keep the socket connected and joined to `user:{id}` globally, not only on the chat screen. Incoming messages are delivered as `message:new` on `user:{recipient_id}`. Sending through `POST /api/messages` also broadcasts `message:new` to the recipient when they are online.

## Example SDP

```json
{
  "sdp": "v=0\r\no=- 461173305 2 IN IP4 127.0.0.1\r\n...",
  "type": "offer"
}
```
