# Push Notifications Toggle in Settings

**Feature:** Push Notifications Toggle
**Priority:** high
**Type:** integration

## Prerequisites
- iOS device (not Simulator — APNs requires real device)
- Alfred server with APNs credentials configured in Secrets Manager
- App has notification permissions granted

## Test Steps
1. Open Settings tab and verify the "Push Notifications" toggle is ON by default.
2. Toggle push notifications OFF.
3. Check server logs or Redis for device token removal (`HDEL alfred:push:devices`).
4. Trigger a notification from the server.
5. Verify NO push notification is received on the device (only in-app via WebSocket if app is open).
6. Toggle push notifications back ON.
7. Verify the device re-registers for remote notifications (`UIApplication.shared.registerForRemoteNotifications()`).
8. Trigger another notification from the server.
9. Close the app and trigger a notification.

## Expected Result
- Step 2: The toggle switches OFF. The app calls `notificationRepository.unregisterDevice()` which sends a DELETE to `/api/devices/register`.
- Step 3: The device token is removed from `alfred:push:devices` Redis hash.
- Step 4-5: No APNs push arrives. If the app is open, in-app WebSocket notifications still work.
- Step 6-7: Toggle switches ON. `UIApplication.shared.registerForRemoteNotifications()` is called, which triggers the AppDelegate to receive the APNs token and register it with the server.
- Step 8: Push notification arrives on the device.
- Step 9: Push notification arrives as a system notification (banner/lock screen).

## Notes
- The toggle state (`pushNotificationsEnabled`) is stored only in the ViewModel's `@Observable` state — it resets to `true` on app relaunch. This may be a bug if the user expects their preference to persist.
- The unregister endpoint is DELETE `/api/devices/register` which requires trusted network access (localhost or Tailscale).
- APNs token registration flows through AppDelegate -> NotificationService -> registerForPushUseCase.
- Edge case: toggle OFF while app has no network — the unregister call will fail silently, but the device will still receive pushes until the token is removed server-side.
- This feature cannot be tested on Simulator since APNs requires a real device.
