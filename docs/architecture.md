# ECall Backend Architecture

ECall is a Phoenix backend for real-time audio/video signaling, presence and messaging.

## Components

- `EcallWeb.UserSocket` authenticates websocket clients with `Phoenix.Token`.
- `user:{id}` channel tracks Phoenix Presence, receives incoming calls and exchanges messages.
- `call:{call_id}` channel relays WebRTC SDP/ICE and call control events between participants.
- `Ecall.Calls.Registry` keeps short-lived call state and enforces the 30 second ringing timeout.
- PostgreSQL stores call history, messages and FCM device tokens.
- CoTURN is provided by Docker Compose for authenticated TURN traffic.

## Data Flow

1. Caller joins `user:{caller_id}` and sends `call:initiate`.
2. Server creates a `calls` row with `ringing` status and broadcasts `call:ringing` to `user:{callee_id}`.
3. If callee has no active Presence, the push layer sends an FCM notification.
4. Both users join `call:{call_id}`.
5. Clients exchange `webrtc:offer`, `webrtc:answer` and `webrtc:ice` events.
6. `call:accept`, `call:reject`, `call:busy`, `call:end` update call history.

## Media

The MVP implements WebRTC signaling. 1:1 calls are expected to use P2P media. Group SFU support is left behind the `call:{call_id}` channel boundary so Membrane can be attached without changing client signaling contracts.
