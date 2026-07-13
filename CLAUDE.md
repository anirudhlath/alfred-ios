# Alfred iOS

Native SwiftUI iOS client for the Alfred ambient multi-agent system.

## Tech Stack

- Swift 6, SwiftUI, iOS 17+
- AlfredKit: local Swift Package for networking + audio (zero external deps)
- Clean Architecture: Domain (entities, protocols, use cases) → Data (repos, mappers) → Presentation (MVVM)
- swift-snapshot-testing for visual regression

## Xcode MCP (NON-NEGOTIABLE)

All Xcode operations MUST go through the native Xcode MCP tools (`xcrun mcpbridge`). This includes:

- **Building:** Use `BuildProject`, NOT `xcodebuild` CLI
- **Testing:** Use `RunAllTests` / `RunSomeTests`, NOT `xcodebuild test`
- **File operations:** Use `XcodeWrite`, `XcodeRead`, `XcodeGlob`, `XcodeGrep`, `XcodeLS`, `XcodeMakeDir`, `XcodeMV`, `XcodeRM` — these keep the Xcode project in sync automatically
- **Previews:** Use `RenderPreview` to capture SwiftUI previews for visual verification
- **Diagnostics:** Use `XcodeListNavigatorIssues`, `XcodeRefreshCodeIssuesInFile`, `GetBuildLog`
- **Documentation:** Use `DocumentationSearch` for Apple API docs
- **Swift REPL:** Use `ExecuteSnippet` for quick Swift evaluation

**Why:** Xcode MCP tools operate within the Xcode project context. Files added via `XcodeWrite` are automatically included in build targets. Using raw `xcodebuild` or filesystem tools bypasses this and can desync the project.

**Exception:** AlfredKit package tests can still use `cd Packages/AlfredKit && swift test` since they're a standalone Swift Package.

## Workflow

```
1. Edit code via Xcode MCP (XcodeWrite/XcodeUpdate)
2. Build via Xcode MCP (BuildProject)
3. Check issues (XcodeListNavigatorIssues)
4. Preview UI (RenderPreview)
5. Run tests (RunAllTests / RunSomeTests)
6. Fix, repeat
```

```bash
# AlfredKit package tests (standalone, no Xcode project needed)
cd Packages/AlfredKit && swift test

# Simulator: build, install, and launch (Debug)
xcodebuild -project Alfred.xcodeproj -scheme Alfred -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/ build
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Alfred.app
xcrun simctl launch booted com.anirudhlath.alfred

# Reset simulator (clears Keychain, UserDefaults, SwiftData)
xcrun simctl erase <device-id>
```

## Key Paths

- `Alfred.xcodeproj` — Xcode project (tracked in git, managed by Xcode)
- `Packages/AlfredKit/` — networking SDK (WebSocket, REST, Audio, DTOs)
  - `Client/WebSocketClient.swift` — single WebSocket connection, `Broadcaster<T>` for multi-consumer streams
  - `Client/ServerMessage.swift` — all server→client message types (response, notification, error, etc.)
  - `Client/ClientMessage.swift` — client→server message encoding (text, audio, channel: "ios")
  - `Audio/AudioRecorder.swift` — AVAudioEngine tap → `AsyncStream<Data>`
  - `Audio/AudioPlayer.swift` — AVAudioPlayer wrapper with async completion
- `App/Alfred/Domain/` — entities, repository protocols, use cases (pure Swift)
- `App/Alfred/Data/` — repository impls, mappers, Keychain, SwiftData
  - `Mappers/MessageMapper.swift` — ServerMessage → Message (response, transcription, error)
  - `Mappers/NotificationMapper.swift` — ServerMessage → AppNotification
  - `Local/MessageStoreImpl.swift` — SwiftData persistence (MessageRecord, ConversationRecord)
  - `Local/KeychainStore.swift` — SecItem wrapper (service: `com.anirudhlath.alfred`)
- `App/Alfred/Presentation/` — SwiftUI views + @Observable ViewModels
- `App/Alfred/DI/AppContainer.swift` — dependency injection + eager notification observation
- `App/Alfred/Services/` — platform services (Audio, Biometric, Notification)
- `Tests/AlfredTests/` — 69 tests (domain, data, presentation, snapshots)
- `docs/qa-backlog/` — manual test cases for hardware/integration features
- `docs/backlog/` — deferred work tickets by priority

## Server Connection

Connects to Alfred backend at `http://<tailscale-ip>:8081` via WebSocket + REST.
Server code lives in the `alfred/` monorepo (separate repo).

## Architecture Notes

- Domain layer is pure Swift — no framework imports except Foundation for UUID/Date
- `AppConnectionState` is the domain-level connection state (not AlfredKit.ConnectionState)
- `AppNotification` is used instead of `Notification` to avoid Foundation name collision
- WebSocketClient uses `Broadcaster<T>` for multi-consumer AsyncStreams — each subscriber (chat, notifications) gets independent copies of all messages
- AppContainer.reconfigure() rewires everything when server config changes — must be followed by `startNotificationObservation()` (called automatically from `ServerConfigViewModel.save()`)
- `ServerConfig.default` is `localhost:8081` in DEBUG, empty host in RELEASE (user must configure in Settings) — Keychain-stored config takes priority

### Notification Pipeline

```
Server → WebSocket → Broadcaster → NotificationRepositoryImpl.rawMessages
  → AppContainer.startNotificationObservation() (eager, runs at startup)
    → .notification → NotificationMapper → pendingNotifications[] → NotificationsView
    → .voiceNotification → AudioPlayer.play() (auto-play, not added to list)
```

- Observation starts in `AlfredApp.task`, NOT on Notifications tab visit
- `NotificationsViewModel.notifications` is a computed property backed by `AppContainer.pendingNotifications`
- `Notification.Name.alfredSessionCleared` bridges Settings → ChatViewModel for session reset

### Message Pipeline

```
Server → WebSocket → Broadcaster → ChatRepositoryImpl.messages
  → MessageMapper → ObserveMessagesUseCase → ChatViewModel
    → append to messages[] + persist to SwiftData
    → if .alfred + audio → AudioPlayer.play()
```

- All incoming messages (Alfred responses + transcriptions) are persisted to SwiftData
- Conversation ID persisted in Keychain, restored on launch

### Voice Pipeline

- `AudioService` wraps `AudioRecorder`/`AudioPlayer` from AlfredKit, injected via `AppContainer`
- Mic tap → `AudioRecorder.start(.aac)` → `AsyncStream<Data>` → chunks collected → `SendVoiceMessageUseCase`
- Audio session configured once at app startup (`AlfredApp.task`)

### Concurrency Model

- `@Observable` + `@MainActor` on all ViewModels — SwiftUI observation is thread-safe
- `@unchecked Sendable` on repository impls and AlfredKit types — mutable state is accessed from MainActor or via cooperative async
- `Broadcaster<T>` uses `NSLock` for thread-safe subscriber management
- Known issue: `AudioPlayer` has unprotected mutable state (see `docs/backlog/medium/architect-review-refactors.md`)

## Testing Gotchas

- **Snapshot PNGs are in Xcode's Copy Bundle Resources** — never delete them from disk; use `withSnapshotTesting(record: .all)` to re-record, then remove the flag
- **Swift 6 concurrency**: XCTestCase classes that create SwiftUI views need `@MainActor`
- **UserDefaults in test host**: `.standard` retains values from prior simulator runs; inject a custom `UserDefaults(suiteName:)` with explicit values for isolation
- **BuildProject vs test build**: `BuildProject` may succeed while test target fails (e.g., missing resources) — always check `GetBuildLog` after test failures
- **Keychain persists across simulator uninstall** — test-written values (e.g. `ServerConfig`) leak into app runs on the same simulator. Tests that write to Keychain must restore defaults in cleanup. Use `xcrun simctl erase` to fully reset.
- **Snapshot device mismatch** — snapshots recorded on one simulator device (e.g. iPhone 16 Pro) fail on another (iPhone 17 Pro). Re-record with `withSnapshotTesting(record: .all)`, run tests, then remove the flag.
