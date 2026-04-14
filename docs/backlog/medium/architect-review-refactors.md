# Architect Review — Deferred Refactors

Issues from the code-architect review that are pre-existing or require larger refactors beyond the wiring scope.

## High Priority

- **AudioPlayer concurrency race (Issue 3):** `AudioPlayer` is `@unchecked Sendable` with unprotected mutable state. Concurrent play calls (notification + chat response) can cause double-resume of continuation. Fix: protect with actor or NSLock.
- **Repository computed props spawn orphaned tasks (Issue 1):** `ChatRepositoryImpl.messages`, `connectionState`, `NotificationRepositoryImpl.rawMessages` create unstructured Tasks per access. After `reconfigure()`, old tasks leak. Fix: create streams once at init, cancel on deinit.
- **Domain layer imports AlfredKit via rawMessages (Issue 4):** `NotificationRepositoryProtocol` exposes `ServerMessage`. Fix: map to domain types inside the repository, expose domain-typed streams.
- **AppContainer contains business logic (Issue 5):** `startNotificationObservation()` does routing/mapping that belongs in a use case. Fix: extract into a proper use case.

## Medium Priority

- **AudioRecorder ignores format param (Issue 18):** Always records raw PCM regardless of `.aac`/`.wav` argument. Server may fail to transcribe raw PCM. Fix: use AVAudioConverter or AVAssetWriter.
- **NotificationsViewModel fragile Observable tracking (Issue 6):** Computed property chain relies on transitive @Observable tracking. Fix: use stored property with explicit observation.
- **WebSocketClient.disconnect() fire-and-forget (Issue 11):** TOCTOU risk on background/active transition. Fix: add async variant or use NSLock instead of actor.
- **AppDelegate Swift 6 violation (Issue 13):** Non-MainActor delegate accesses @MainActor NotificationService. Fix: mark delegate methods @MainActor.

## Low Priority

- **ConnectUseCase thin wrapper (Issue 16):** Holds unused sessionRepo dependency. Consider removing.
- **ModelContainer force_try (Issue 14):** No migration strategy. Fix: add error handling and fallback.
- **requestAuthorization swallows errors (Issue 19):** No user feedback on auth failure.
