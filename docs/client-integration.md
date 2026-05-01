# Client Integration

## Core Rule

After login, the app must keep one global Phoenix socket connected and joined to:

```text
user:{myUserId}
```

Chats and calls should subscribe to app-level events from this global channel. Do not create listeners only inside a chat screen.

## Auth

Login:

```http
POST /api/auth/login
Content-Type: application/json
```

```json
{"email":"user@example.com","password":"secret123"}
```

Store `user.id`, `access_token`, `refresh_token`.

REST:

```text
Authorization: Bearer <access_token>
```

WebSocket:

```text
wss://ecall.everty.ru/socket/websocket?token=<access_token>&vsn=2.0.0
```

The WebSocket query value is the raw JWT, without `Bearer `.

## Messaging Flow

Required ids:

- `myUserId`: logged-in user id from auth response.
- `peerUserId`: selected chat/call partner id.

Never request a normal chat as:

```text
/api/conversations/{myUserId}/{myUserId}/messages
```

Correct history request:

```text
GET /api/conversations/{myUserId}/{peerUserId}/messages?limit=50
```

Send message:

```http
POST /api/messages
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{"to":"peerUserId","body":"Hello","client_message_id":"local-uuid"}
```

Recipient receives on global channel:

```text
topic: user:{peerUserId}
event: message:new
```

Use `client_message_id` for retries. If the HTTP request times out, retry with the same `client_message_id`.

On reconnect, sync missed messages:

```text
GET /api/users/{myUserId}/messages/sync?since=<last_message_inserted_at>&limit=200
```

Apply messages idempotently by backend `id`.

## Call Flow

1. Both users are logged in and joined to `user:{myUserId}`.
2. Caller sends on `user:{callerId}`:

```json
{"to":"calleeId","media":"video","client_call_id":"local-call-uuid"}
```

Event name:

```text
call:initiate
```

3. Callee receives on `user:{calleeId}`:

```text
call:ringing
```

4. Callee sends `call:ringing_ack` on `user:{calleeId}`:

```json
{"call_id":"call-uuid"}
```

5. Both users join:

```text
call:{call_id}
```

6. Callee sends:

```text
call:accept
```

7. WebRTC signaling:

```text
webrtc:offer
webrtc:answer
webrtc:ice
```

8. Finish with:

```text
call:end
```

State rules:

- Only callee sends `call:accept`, `call:reject`, `call:busy`.
- Either side may send `call:end`.
- After `call:end`, `call:reject`, `call:busy`, `call:timeout`, leave `call:{call_id}` and clear local active call.
- Redial must create a new `client_call_id`.
- Do not join old or terminal `call_id`.

## WebRTC

Fetch ICE servers after login:

```text
GET /api/webrtc/ice_servers
Authorization: Bearer <access_token>
```

Use response `data` as:

```kotlin
PeerConnection.RTCConfiguration(iceServers)
```

Backend only relays signaling. Audio/video media goes P2P through WebRTC, with TURN fallback when NAT blocks direct traffic.

For network handover:

- keep the same `call_id`
- do not send `call:end` immediately
- send `call:reconnecting`
- reconnect socket
- fetch `GET /api/users/{myUserId}/calls/active`
- rejoin `call:{call_id}`
- restart ICE and send a new `webrtc:offer`
- send `call:reconnected` when media flows again

## Diagnostics

Expected after login:

```text
JOINED user:{myUserId}
```

Expected incoming message:

```text
Last event: user:{myUserId} / message:new
```

Expected incoming call:

```text
Last event: user:{myUserId} / call:ringing
```

If REST send returns `200` but recipient sees no event:

- verify recipient is joined to `user:{recipientId}`
- verify payload uses `"to":"recipientId"`, not `"to":"myUserId"`
- verify chat history uses `{myUserId}/{peerUserId}`, not `{myUserId}/{myUserId}`

If call join is refused:

- the user is not caller/callee of that `call_id`, or
- the call is already terminal, or
- Android is using stale local call state
