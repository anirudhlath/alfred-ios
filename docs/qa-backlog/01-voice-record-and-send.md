# Voice Recording and Send

**Feature:** Voice Pipeline (mic button -> record -> send -> auto-play response)
**Priority:** critical
**Type:** e2e

## Prerequisites
- Alfred server running with Whisper STT and Piper TTS enabled
- iOS device or Simulator with microphone access
- Server reachable over network (localhost or Tailscale)

## Test Steps
1. Launch the app and complete onboarding so the Chat tab is visible.
2. Tap the microphone button in the chat input area.
3. Grant microphone permission when the system dialog appears.
4. Speak a clear sentence (e.g., "What is the weather right now?").
5. Tap the microphone button again to stop recording.
6. Observe the chat view while the server processes the voice message.

## Expected Result
- Step 2: The mic button should visually indicate recording state (isRecording = true).
- Step 3: The system permission dialog appears on first tap only; subsequent taps start recording immediately.
- Step 5: Recording stops, a user message appears in the chat (transcribed text from the server), and a waiting indicator shows.
- Step 6: An Alfred response message appears. If the response includes audio data, it auto-plays through the device speaker without any user action.

## Notes
- The audio is sent as AAC format via SendVoiceMessageUseCase. Verify the server STT receives the correct format hint (`.aac` suffix) by checking server logs for "Transcribed voice".
- If microphone permission is denied, tapping the mic button should silently fail (no crash, no recording).
- Test with AirPods connected to verify audio session routing works with Bluetooth output.
- Edge case: tap mic button rapidly on/off — should not crash or leave orphan recording sessions.
- Edge case: record silence (no speech) — server should return empty or minimal transcription, app should handle gracefully (no empty user bubble).
