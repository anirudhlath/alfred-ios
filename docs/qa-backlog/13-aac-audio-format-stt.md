# AAC Audio Format Server-Side Transcription

**Feature:** Multi-format audio STT (AAC from iOS, WebM from web)
**Priority:** high
**Type:** integration

## Prerequisites
- Alfred server running with Whisper STT (large-v3-turbo)
- ffmpeg installed on server (required for AAC decoding)
- iOS app connected

## Test Steps
1. Send a voice message from the iOS app.
2. Check server logs for the audio format detected in `_decode_audio()`.
3. Check server logs for the STT transcription result.
4. Verify the transcribed text appears in the chat as a user message (via the `transcription` WebSocket response).
5. Open the web PWA and send a voice message from the browser.
6. Verify the web voice message uses WebM format and transcribes correctly.

## Expected Result
- Step 2: Server logs should show the audio format as "aac" (extracted from the data URL MIME type `data:audio/aac;base64,...`).
- Step 3: Whisper STT creates a temp file with `.aac` suffix and transcribes successfully. Log shows "Transcribed voice -> 'N' chars".
- Step 4: The transcribed text is sent back as a `transcription` message and appears as a user bubble in chat.
- Step 5-6: Web PWA sends WebM format, server handles it with `.webm` suffix. Both formats coexist.

## Notes
- The iOS app records in AAC format (`.aac`), while the web PWA records in WebM. The server's `_decode_audio()` now extracts the format from the data URL MIME type and passes it as `audio_format` to `stt.transcribe()`.
- Whisper relies on ffmpeg for non-WAV formats. If ffmpeg is not installed, AAC transcription will fail silently.
- The suffix hint is important — without it, Whisper would try to decode AAC data as WAV and fail.
- Edge case: if the iOS app sends a data URL without a MIME type header, the server defaults to "wav" format, which would fail for AAC data.
