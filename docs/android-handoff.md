# Android Handoff

Give Android these files:

- `docs/api.md`
- `docs/client-integration.md`
- `docs/android-handoff.md`

## URLs

```text
API: https://ecall.everty.ru
WebSocket: wss://ecall.everty.ru/socket/websocket?token=<access_token>&vsn=2.0.0
```

## Minimum Integration Checklist

1. Login/register and store `user.id`, `access_token`, `refresh_token`.
2. Connect WebSocket with raw `access_token`.
3. Join `user:{user.id}` immediately after socket connect.
4. Keep `user:{user.id}` joined globally while the user is logged in.
5. Use `peerUserId` for chats and calls.
6. Send messages with `"to":"peerUserId"`.
7. Fetch chat history with `/api/conversations/{myUserId}/{peerUserId}/messages`.
8. Listen for `message:new` globally and update chat list even when chat screen is closed.
9. Listen for `call:ringing` globally and show incoming-call UI.
10. Join `call:{call_id}` only for the current active call.
11. Clear active call after `call:end`, `call:reject`, `call:busy`, `call:timeout`.
12. Fetch `/api/webrtc/ice_servers` and use it for WebRTC.

## Common Mistakes

Wrong chat history:

```text
/api/conversations/{myUserId}/{myUserId}/messages
```

Correct:

```text
/api/conversations/{myUserId}/{peerUserId}/messages
```

Wrong message:

```json
{"to":"myUserId","body":"hello"}
```

Correct:

```json
{"to":"peerUserId","body":"hello"}
```

Wrong WebSocket token:

```text
?token=Bearer <access_token>
```

Correct:

```text
?token=<access_token>
```

## Do Not Share

Do not put backend secrets into the Android app:

- `POSTGRES_PASSWORD`
- `SECRET_KEY_BASE`
- `JWT_SECRET`
- `TURN_PASSWORD`
- `FCM_ACCESS_TOKEN`

Android receives TURN config from:

```text
GET /api/webrtc/ice_servers
```
