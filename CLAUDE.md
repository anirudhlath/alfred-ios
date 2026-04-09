# Alfred iOS

Native SwiftUI iOS client for the Alfred ambient multi-agent system.

## Tech Stack

- Swift 6, SwiftUI, iOS 17+
- XcodeGen for project generation (`.xcodeproj` is gitignored)
- AlfredKit: local Swift Package for networking + audio (zero external deps)
- Clean Architecture: Domain (entities, protocols, use cases) → Data (repos, mappers) → Presentation (MVVM)
- swift-snapshot-testing for visual regression

## Tooling

- **Xcode 26.3+** with native MCP enabled (Settings → Intelligence → Enable Model Context Protocol)
- **XcodeGen** (`brew install xcodegen`) — generates .xcodeproj from project.yml
- **Xcode MCP bridge** (`xcrun mcpbridge`) — configured in Claude Code, provides 20 native tools for build, test, preview capture, simulator control, symbol navigation
- No need for third-party build MCPs — Xcode's native MCP replaces XcodeBuildMCP

## Workflow

```bash
xcodegen generate                    # regenerate .xcodeproj from project.yml
cd Packages/AlfredKit && swift test  # AlfredKit package tests (no simulator needed)
```

Build, test, and simulator tasks should use the Xcode MCP tools when Xcode is running. Fallback:
```bash
xcodebuild -scheme Alfred -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcodebuild -scheme Alfred -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

## Key Paths

- `project.yml` — XcodeGen spec (source of truth for project structure)
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
