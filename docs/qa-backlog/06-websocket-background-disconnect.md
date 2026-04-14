# WebSocket Disconnect on Background / Reconnect on Foreground

**Feature:** WebSocket Disconnect on Background
**Priority:** critical
**Type:** functional

## Prerequisites
- Alfred server running
- iOS device (not Simulator — Simulator background behavior differs)
- Active chat session with messages

## Test Steps
1. Open the app and verify WebSocket is connected (send a message, get a response).
2. Press the Home button or swipe up to send the app to background.
3. Wait 5 seconds.
4. Check server logs for WebSocket disconnect.
5. Open the app again (bring to foreground).
6. Immediately send a message.
7. Repeat steps 2-6 but wait 30 seconds in background.
8. Repeat steps 2-6 but wait 5 minutes in background.

## Expected Result
- Step 2: The app calls `chatRepository.disconnect()` when scenePhase changes to `.background`.
- Step 4: Server logs show "WebSocket disconnected" for the iOS session.
- Step 5: The app calls `connectUseCase.execute()` when scenePhase changes to `.active`. Connection re-establishes.
- Step 6: Message sends successfully on the reconnected WebSocket. Session ID is preserved (server assigns new session immediately on accept, but client can restore previous session_id).
- Step 7-8: Same behavior regardless of background duration. The reconnect with exponential backoff should handle any delay.

## Notes
- The disconnect/reconnect is driven by `scenePhase` in AlfredApp.swift using `.onChange(of: scenePhase)`.
- The Broadcaster pattern means both chat and notification streams get new subscriptions on reconnect.
- iOS may suspend the app after ~30s in background — the disconnect call in step 2 should fire before suspension.
- Edge case: rapid foreground/background toggling (e.g., switching between apps quickly) — should not cause race conditions or multiple simultaneous WebSocket connections.
- Edge case: server goes down while app is in background. On foreground, reconnect should retry with exponential backoff.
