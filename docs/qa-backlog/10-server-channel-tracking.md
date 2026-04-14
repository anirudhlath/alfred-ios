# Server-Side iOS Channel Tracking

**Feature:** Server-Side Channel Tracking (ios vs web_pwa)
**Priority:** high
**Type:** integration

## Prerequisites
- Alfred server running (from the ios-server-changes worktree or equivalent)
- iOS app connected via WebSocket
- Web PWA also connected via WebSocket (open browser to server URL)

## Test Steps
1. Connect the iOS app to the server. Observe server logs for the WebSocket connection.
2. Send a message from the iOS app.
3. Check the server's `_active_websockets` dict (via logs or debugger) to verify the iOS connection is tracked with channel "ios".
4. Open the web PWA in a browser and connect.
5. Verify the web PWA connection is tracked with channel "web_pwa".
6. Trigger a WebSocket notification from the server.
7. Verify the notification is delivered ONLY to the web_pwa WebSocket, NOT to the iOS WebSocket.
8. Trigger an APNs notification.
9. Verify the iOS device receives it via APNs push.
10. Disconnect the iOS app (background it) and verify the server removes the iOS entry from `_active_websockets`.

## Expected Result
- Step 1: Server logs show new WebSocket connection. Initial channel is "web_pwa" (default), then updated to "ios" when the iOS client sends its first message with `channel: "ios"`.
- Step 2-3: The UserRequest created by the server has `source: "ios-app"` and `channel: "ios"`.
- Step 5: Web PWA tracked separately as "web_pwa".
- Step 6-7: `get_web_websockets()` returns only web_pwa connections. The WebSocketChannelAdapter uses this to avoid duplicate notifications on iOS (since iOS gets APNs instead).
- Step 8-9: APNs adapter reads from `alfred:push:devices` and sends to the registered iOS device token.
- Step 10: Server logs "WebSocket disconnected", entry removed from dict.

## Notes
- The channel is sent by the iOS client in each message payload as `"channel": "ios"`. The server validates it against allowed values ("web_pwa", "voice", "ios") and defaults to "web_pwa" if invalid.
- The `get_web_websockets()` function filters out iOS connections so that the WebSocket notification adapter and Voice notification adapter don't push to iOS clients (they get APNs instead).
- The session_id is now sent immediately on WebSocket accept (before any client message), which prevents iOS clients from deadlocking while waiting for the session message.
- `_CHANNEL_SOURCE_MAP` maps "ios" -> "ios-app" for the UserRequest source field.
