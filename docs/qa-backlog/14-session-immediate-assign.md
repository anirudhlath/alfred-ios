# Immediate Session ID Assignment on WebSocket Connect

**Feature:** Server-side session tracking (immediate session send)
**Priority:** high
**Type:** regression

## Prerequisites
- Alfred server running (ios-server-changes branch)
- iOS app or web PWA client

## Test Steps
1. Launch the iOS app and monitor the WebSocket connection.
2. Observe the first message received from the server after connection.
3. Verify the app receives a `session` message with a `session_id` BEFORE sending any client message.
4. Send a first message from the app.
5. Verify the message includes the app's previously stored `session_id` (if reconnecting) or uses the server-assigned one.
6. Disconnect and reconnect (background/foreground the app).
7. Verify the server sends a new session_id immediately on reconnect.
8. Verify the client's first message includes the old session_id to restore the previous session.

## Expected Result
- Step 2-3: The server sends `{"type": "session", "session_id": "<uuid>"}` immediately after WebSocket accept, before waiting for any client message.
- Step 5: The client's message includes `session_id` from Keychain. The server updates its internal session_id to match the client's restored value.
- Step 7-8: Same flow — server assigns eagerly, client overrides with stored value on first message.

## Notes
- This fixes a deadlock where the iOS client waited for the session message before sending, but the old server waited for the client's first message before sending the session. Neither side would proceed.
- The old flow was: client sends first message with optional session_id -> server assigns/restores and sends session message. The new flow is: server assigns immediately -> client sends first message with optional override.
- Web PWA clients should also work correctly with this change since they previously sent a message first and now just get the session earlier.
