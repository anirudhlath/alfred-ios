# Server Error Display in Chat

**Feature:** Server Error Display (ServerMessage.error mapped to chat)
**Priority:** high
**Type:** functional

## Prerequisites
- Alfred server running
- Active WebSocket connection

## Test Steps
1. Send a message that triggers a server-side error (e.g., a request that exceeds the cost cap, or trigger an integration that has no credentials configured).
2. Observe the chat view.
3. Send a normal follow-up message after the error.

## Expected Result
- Step 2: The error message from the server appears as an Alfred message bubble in the chat. The waiting indicator dismisses.
- Step 3: The conversation continues normally — the error message does not block subsequent interactions.

## Notes
- The `ServerMessage.error` case is now mapped via `MessageMapper` to a `Message(role: .alfred)`. Previously, errors were silently dropped.
- Hard to trigger organically — may need to artificially cause a server error (e.g., stop Redis while server is running, or send malformed content type).
- Verify the error text is user-readable, not a raw stack trace.
