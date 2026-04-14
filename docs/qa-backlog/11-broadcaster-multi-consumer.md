# Broadcaster Multi-Consumer WebSocket Streams

**Feature:** Broadcaster pattern for WebSocket message fan-out
**Priority:** critical
**Type:** regression

## Prerequisites
- Alfred server running
- iOS app connected

## Test Steps
1. Launch the app and ensure both chat and notification observation are active.
2. Send a text message and verify it appears in chat.
3. Trigger a notification from the server.
4. Verify the notification appears in the Notifications tab.
5. Send another text message and verify it still appears in chat.
6. Background the app and bring it back to foreground (triggers reconnect).
7. Send a message after reconnect.
8. Trigger a notification after reconnect.
9. Verify both chat messages and notifications continue to work after reconnect.

## Expected Result
- Steps 2-5: Both consumers (ChatViewModel and AppContainer notification observer) independently receive all WebSocket messages. Chat messages appear in chat; notifications appear in notifications. Neither consumer steals messages from the other.
- Steps 6-9: After reconnect, new `AsyncStream` subscriptions are created via `Broadcaster.subscribe()`. Both consumers resume receiving messages independently.

## Notes
- This is a regression test for the previous bug where `AsyncStream` with a single continuation meant only one consumer could read each message. The Broadcaster fix creates independent subscriber streams.
- The previous implementation used a single `AsyncStream` with one continuation — whichever consumer read first got the message, and the other missed it.
- After reconnect, `WebSocketClient.messages` and `WebSocketClient.connectionState` return new subscriber streams from the broadcaster. Verify that old subscriptions are cleaned up (no memory leak from abandoned streams).
- Critical path: if this breaks, either chat OR notifications will silently stop working.
