# Notification Audio Auto-Playback

**Feature:** Audio Playback for Notifications (voice notifications auto-play when app active)
**Priority:** high
**Type:** integration

## Prerequisites
- Alfred server running with notification system enabled
- A trigger or scheduled event that generates a voice notification (e.g., DND drain, proactive notification with TTS)
- App in foreground

## Test Steps
1. Launch the app and ensure WebSocket is connected (chat tab shows connected state).
2. Trigger a voice notification from the server (e.g., via the trigger engine or manually publish to the notification dispatch stream with urgency=URGENT).
3. Observe audio playback and the Notifications tab.
4. Switch to the Notifications tab.
5. Find a notification with the speaker icon and tap it.
6. Trigger a text-only notification (no audio payload).
7. Switch to the Notifications tab.

## Expected Result
- Step 2-3: The voice notification's audio auto-plays immediately through the device speaker, regardless of which tab is active. The notification also appears in the Notifications tab list.
- Step 5: Tapping the speaker icon replays the audio. The icon changes to `speaker.wave.3.fill` while playing, then reverts to `speaker.wave.2` when done.
- Step 6-7: The text notification appears in the Notifications tab without any audio playback attempt.

## Notes
- Voice notifications are captured in `AppContainer.startNotificationObservation()` which runs at app startup — this is the "eager observation" pattern.
- The `pendingNotifications` array is shared between AppContainer and NotificationsViewModel via a computed property binding.
- Auto-play happens via `audioService.player.play(audio)` in AppContainer, not in the ViewModel.
- Edge case: if a voice notification arrives while the user is recording audio (mic active), does the playback interrupt the recording?
- Edge case: multiple voice notifications in quick succession — do they queue or overlap?
