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

## Key Paths

- `Alfred.xcodeproj` — Xcode project (tracked in git, managed by Xcode)
- `Packages/AlfredKit/` — networking SDK (WebSocket, REST, Audio, DTOs)
- `App/Alfred/Domain/` — entities, repository protocols, use cases (pure Swift)
- `App/Alfred/Data/` — repository impls, mappers, Keychain, SwiftData
- `App/Alfred/Presentation/` — SwiftUI views + @Observable ViewModels
- `App/Alfred/DI/AppContainer.swift` — dependency injection wiring
- `App/Alfred/Services/` — platform services (Audio, Biometric, Notification)
- `Tests/AlfredTests/` — app target tests (domain, data, presentation, snapshots)

## Server Connection

Connects to Alfred backend at `http://<tailscale-ip>:8081` via WebSocket + REST.
Server code lives in the `alfred/` monorepo (separate repo).

## Architecture Notes

- Domain layer is pure Swift — no framework imports except Foundation for UUID/Date
- `AppConnectionState` is the domain-level connection state (not AlfredKit.ConnectionState)
- `AppNotification` is used instead of `Notification` to avoid Foundation name collision
- WebSocketClient is a singleton shared between Chat and Notification repositories
- AppContainer.reconfigure() rewires everything when server config changes

## Testing Gotchas

- **Snapshot PNGs are in Xcode's Copy Bundle Resources** — never delete them from disk; use `withSnapshotTesting(record: .all)` to re-record, then remove the flag
- **Swift 6 concurrency**: XCTestCase classes that create SwiftUI views need `@MainActor`
- **UserDefaults in test host**: `.standard` retains values from prior simulator runs; inject a custom `UserDefaults(suiteName:)` with explicit values for isolation
- **BuildProject vs test build**: `BuildProject` may succeed while test target fails (e.g., missing resources) — always check `GetBuildLog` after test failures
