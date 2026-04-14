# Eager Notification Observation at Startup

**Feature:** Notification Eager Observation
**Priority:** high
**Type:** functional

## Prerequisites
- Alfred server running with notification system
- App freshly launched

## Test Steps
1. Launch the app. Stay on the Chat tab (do NOT navigate to Notifications).
2. Trigger a text notification from the server.
3. Trigger a voice notification from the server.
4. Now navigate to the Notifications tab.
5. Verify notifications are present.
6. Force-quit and relaunch the app.
7. Navigate directly to the Notifications tab before any notifications are sent.
8. Trigger a notification.
9. Verify it appears in real time.

## Expected Result
- Step 2-3: Notifications are captured in `AppContainer.pendingNotifications` even though the Notifications tab has never been opened. Voice notification audio auto-plays.
- Step 4-5: Both notifications appear immediately in the list (no loading delay, no empty state).
- Step 6-7: The Notifications tab starts empty (pendingNotifications is in-memory only, not persisted).
- Step 8-9: The notification appears in the list in real time.

## Notes
- `startNotificationObservation()` is called in the `.task` modifier of AlfredApp, which runs once at app startup. It is guarded by `notificationObservationStarted` to prevent double-subscription.
- Previous implementation started observation in `NotificationsViewModel.configure()` — which only ran when the user navigated to the tab. This caused missed notifications.
- Notifications are NOT persisted across app restarts — `pendingNotifications` is an in-memory array on AppContainer.
- The Broadcaster pattern on WebSocketClient ensures both the chat message consumer and the notification consumer each receive all messages independently.
