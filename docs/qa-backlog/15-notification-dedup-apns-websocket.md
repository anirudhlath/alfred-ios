# Notification Deduplication Between APNs and WebSocket

**Feature:** notification_id deduplication across channels
**Priority:** high
**Type:** integration

## Prerequisites
- iOS device with APNs configured
- Alfred server with both APNs adapter and WebSocket adapter active
- iOS app in foreground with WebSocket connected

## Test Steps
1. With the iOS app open and connected, trigger a notification from the server.
2. Observe whether the notification arrives via WebSocket (in-app) AND via APNs (system push).
3. Check the Notifications tab for duplicate entries.
4. Background the app.
5. Trigger another notification.
6. Observe whether the notification arrives only via APNs (since WebSocket is disconnected).
7. Bring the app to foreground and check the Notifications tab.

## Expected Result
- Step 1-2: The notification should arrive in-app via WebSocket only. The WebSocket adapter uses `get_web_websockets()` which excludes iOS connections, so the iOS WebSocket should NOT receive it. The APNs adapter should deliver via push. However, since the app is in foreground, the APNs notification should be handled by the foreground notification handler (deduplication via `notification_id`).
- Step 3: No duplicate entries in the Notifications tab. The `notification_id` field (now included in both WebSocket and APNs payloads) enables deduplication.
- Step 5-6: With WebSocket disconnected, only APNs delivers the notification. It appears as a system banner/notification.
- Step 7: The notification from step 5 should be visible in the Notifications tab (if the app captures it on relaunch or the user taps the banner).

## Notes
- The server's `get_web_websockets()` function excludes iOS connections from WebSocket notification delivery to prevent duplicates (iOS gets APNs instead).
- The `notification_id` field is now included in both the WebSocket payload (`notification.notification_id`) and the APNs payload. The iOS app uses this for foreground deduplication.
- IMPORTANT: If the iOS WebSocket is still tracked as "web_pwa" (before the first message sets the channel to "ios"), the WebSocket adapter WILL send to it, causing duplicates. Verify the channel is set correctly on first message.
- Edge case: app transitions from foreground to background during notification delivery — both channels may fire.
