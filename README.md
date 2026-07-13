# Alfred iOS

Native SwiftUI client for [Alfred](https://github.com/anirudhlath/alfred), a self-hosted multi-agent assistant. Text and voice chat with streaming responses, push notifications, and integration management — all against your own Alfred server over your private network (e.g. Tailscale).

This is a personal-infrastructure project: it targets a self-hosted backend and is not distributed on the App Store.

## Features

- **Chat** — text conversations over a single WebSocket connection; messages persisted with SwiftData and restored on launch, conversation ID kept in the Keychain
- **Voice** — mic capture via an AVAudioEngine tap streamed as `AsyncStream<Data>` chunks and sent over the WebSocket; audio replies and voice notifications auto-play
- **Notifications** — APNs device registration for background delivery, plus a live WebSocket notification stream observed eagerly from app startup (APNs banners are suppressed in the foreground to avoid duplicates)
- **Onboarding** — multi-step wizard for preferences, proactivity level, guest access, and integrations
- **Integrations** — view and configure server-side integration credentials from Settings
- **App lock** — Face ID / passcode gate via LocalAuthentication
- **Server config** — host and port stored in the iOS Keychain, editable in Settings with a built-in connection test

## Architecture

Clean Architecture: an app target layered over a local Swift package, with dependencies pointing inward.

```
Presentation  (SwiftUI views + @Observable ViewModels, MVVM)
      ↓
   Domain     (entities, repository protocols, use cases — pure Swift)
      ↑
    Data      (repository impls, mappers, Keychain, SwiftData)
      ↑
  AlfredKit   (local Swift package: WebSocket + REST clients, DTOs, audio — zero external dependencies)
```

Notable details:

- **Swift 6 strict concurrency** — `@MainActor` ViewModels, `Sendable` domain types
- **`Broadcaster<T>`** — a thread-safe multi-consumer fan-out over `AsyncStream`, so chat and notifications each receive an independent copy of every server message from the one WebSocket connection
- **`AppContainer`** — hand-rolled dependency injection; rewires clients, repositories, and use cases when the server config changes
- The Domain layer imports nothing but Foundation; AlfredKit has no third-party dependencies

Message flow:

```
Server → WebSocket → Broadcaster ─┬→ ChatRepository → MessageMapper → ChatViewModel → SwiftData
                                  └→ NotificationRepository → NotificationMapper → Notifications UI
```

## Requirements

- Xcode 16 or newer (Swift 6 toolchain)
- iOS 17.0+ deployment target
- A running [Alfred server](https://github.com/anirudhlath/alfred) reachable from the device — typically over a Tailscale network, which acts as the trust boundary (no in-app auth)

## Build and run

1. Open `Alfred.xcodeproj` in Xcode.
2. For device installs, set your own team under Signing & Capabilities (the checked-in project references the author's team). Simulator builds work as-is.
3. Build and run the `Alfred` scheme.

Configure the server address in **Settings → Server Config** (host + port, with a connection test). The value is stored in the Keychain and takes priority over defaults. Debug builds default to `localhost:8081`; release builds have no default host, so configuration is required.

Command-line simulator build:

```bash
xcodebuild -project Alfred.xcodeproj -scheme Alfred -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/ build
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Alfred.app
xcrun simctl launch booted com.anirudhlath.alfred
```

Push notifications require an Apple Developer APNs entitlement and the server's APNs adapter; without them the app still delivers notifications through the WebSocket stream while foregrounded.

## Testing

Tests use Swift Testing (`#expect`) plus [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) for visual regression.

```bash
# AlfredKit package tests — standalone, no simulator required
cd Packages/AlfredKit && swift test
```

App-target tests (domain, data, presentation, snapshots) run through Xcode (Cmd-U) on a simulator. Notes:

- Snapshot references live in `Tests/AlfredTests/Presentation/__Snapshots__/` and are tied to the simulator model they were recorded on; re-record with `withSnapshotTesting(record: .all)` if yours differs
- Keychain state persists across simulator runs; use `xcrun simctl erase <device-id>` for a clean slate

## Project layout

- `App/Alfred/Domain/` — entities, repository protocols, use cases
- `App/Alfred/Data/` — repository implementations, mappers, Keychain, SwiftData
- `App/Alfred/Presentation/` — SwiftUI views and ViewModels (Chat, Notifications, Onboarding, Settings)
- `App/Alfred/DI/AppContainer.swift` — dependency wiring
- `App/Alfred/Services/` — platform services (audio session, biometrics, notifications)
- `Packages/AlfredKit/` — networking and audio SDK (WebSocket, REST, DTOs, recorder/player)
- `Tests/` — app-target tests; package tests live under `Packages/AlfredKit/Tests/`
- `docs/` — design specs, implementation plans, and backlog/QA tickets

## License

MIT — see [LICENSE](LICENSE).
