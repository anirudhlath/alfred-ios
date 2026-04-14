# Audio Response Auto-Playback

**Feature:** Voice Pipeline (auto-play audio responses in chat)
**Priority:** critical
**Type:** functional

## Prerequisites
- Alfred server running with TTS enabled (Piper TTS with Alan voice)
- iOS device with speaker or headphones
- Active chat session

## Test Steps
1. Send a text message that will produce a TTS response (e.g., "Tell me a joke").
2. Observe the chat when the Alfred response arrives.
3. While audio is playing, send another message immediately.
4. Wait for the second response with audio.
5. Put the device on silent/mute (ring/silent switch) and send another message.
6. Connect AirPods, send another message, and observe audio routing.

## Expected Result
- Step 2: Audio plays automatically when the Alfred message with audio data appears. No manual play button needed.
- Step 3-4: The second audio response should play after the first finishes (or interrupt it — document observed behavior).
- Step 5: Verify whether audio plays through speaker on silent mode (depends on AVAudioSession category configured in `configureAudioSession()`).
- Step 6: Audio routes to AirPods correctly.

## Notes
- The audio playback is triggered in ChatViewModel when `message.audio != nil` for alfred messages.
- AudioService is configured at app launch via `configureAudioSession()` in AlfredApp.swift.
- There is no queue for multiple audio responses — concurrent playback behavior should be documented.
- Test with Do Not Disturb enabled to ensure audio still plays (it should, since this is in-app playback, not a system notification).
