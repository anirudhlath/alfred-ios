# Alfred iOS App — Design Spec

**Date:** 2026-04-03
**Status:** Draft
**Repo:** `alfred-ios` → `github.com/anirudhlath/alfred-ios`

## Overview

Native SwiftUI iOS client for Alfred, providing full feature parity with the existing web PWA plus native iOS capabilities. Connects to the existing Python backend via WebSocket + REST over Tailscale VPN. Distributed via personal TestFlight only.

## Goals

- Full conversational interface (text + voice) with Alfred
- Native push notifications via APNs (primary delivery channel for iOS)
- Onboarding wizard matching web PWA flow
- Integration and credential management
- Face ID / passcode app lock
- Architecture that supports future Siri Shortcuts, widgets, and Live Activities

## Non-Goals (v1)

- Siri Shortcuts / App Intents
- Home screen / lock screen widgets
- Live Activities
- Offline capability / on-device inference
- App Store distribution
- Custom auth system (Tailscale is the trust boundary)
- Android support

---

## Architecture

### Clean Architecture

The app follows Clean Architecture with a single reusable Swift Package (AlfredKit) and domain types within the app target.

```
Presentation (Views + ViewModels)
       ↓
    Domain (Entities, Repository Protocols, Use Cases)
       ↑
    Data (Repository Implementations, Mappers, Local Storage)
       ↑
    AlfredKit (Swift Package — Networking + Audio)
```

**Dependency rule:** Dependencies point inward. Presentation depends on Domain. Data depends on Domain and AlfredKit. Domain depends on nothing.

### Project Structure

```
alfred-ios/
├── project.yml                     # XcodeGen spec (.xcodeproj is gitignored)
├── Packages/
│   └── AlfredKit/                  # Swift Package — networking SDK
│       ├── Package.swift
│       ├── Sources/
│       │   └── AlfredKit/
│       │       ├── Client/         # WebSocketClient, RESTClient
│       │       ├── DTOs/           # Codable structs (wire format)
│       │       └── Audio/          # AudioRecorder, AudioPlayer
│       └── Tests/
│           └── AlfredKitTests/
├── App/
│   └── Alfred/
│       ├── AlfredApp.swift         # Entry point, Face ID gate
│       │
│       ├── DI/                     # Dependency injection
│       │   └── AppContainer.swift  # Wires implementations to protocols
│       │
│       ├── Domain/                 # Pure Swift, no framework imports
│       │   ├── Entities/           # Message, Conversation, Notification, etc.
│       │   ├── Repositories/       # Protocol definitions
│       │   └── UseCases/           # Business logic orchestration
│       │
│       ├── Data/                   # Implements Domain protocols
│       │   ├── Repositories/       # ChatRepositoryImpl, etc.
│       │   ├── Mappers/            # DTO <-> Entity
│       │   └── Local/              # KeychainStore, SwiftData models
│       │
│       ├── Presentation/           # SwiftUI views + ViewModels
│       │   ├── Chat/
│       │   ├── Notifications/
│       │   ├── Settings/
│       │   ├── Onboarding/
│       │   └── Components/
│       │
│       ├── Services/               # Platform services (AudioService, BiometricService)
│       └── Resources/              # Assets.xcassets, Info.plist
│
├── Tests/
│   └── AlfredTests/
│       ├── Domain/                 # Use case tests
│       ├── Data/                   # Repository + mapper tests
│       └── Presentation/          # ViewModel + snapshot tests
│
└── .gitignore
```

---

## AlfredKit — Networking SDK

Standalone Swift Package. Zero external dependencies. Only Apple frameworks: Foundation, AVFoundation.

### WebSocketClient

```swift
protocol WebSocketClientProtocol {
    func connect(to url: URL, sessionId: String?) async throws
    func disconnect()
    func send(_ message: ClientMessage) async throws
    var messages: AsyncStream<ServerMessage> { get }
    var connectionState: AsyncStream<ConnectionState> { get }
}

enum ConnectionState {
    case disconnected
    case connecting
    case connected(sessionId: String)
}

enum ClientMessage {
    case text(content: String, identity: String, channel: String = "ios")
    case audio(data: Data, mimeType: String, identity: String, channel: String = "ios")
}

enum ServerMessage {
    case session(sessionId: String)
    case response(text: String, sessionId: String, audio: Data?)
    case transcription(text: String, sessionId: String)
    case notification(title: String, body: String, urgency: String)
    case voiceNotification(title: String, audio: Data)
    case error(text: String, sessionId: String)
}
```

- Built on `URLSessionWebSocketTask`
- Auto-reconnect with exponential backoff (1s to 10s, matching web PWA)
- Session ID sent in the first WebSocket message payload (same as web PWA), not in URL params
- `channel` field included in every client message so the server can set `channel="ios"` on the `UserRequest`
- All messages are JSON-encoded `Codable` DTOs

### RESTClient

```swift
protocol RESTClientProtocol {
    func getIntegrations() async throws -> [IntegrationDTO]
    func saveCredentials(integration: String, fields: [String: String]) async throws
    func deleteCredentials(integration: String) async throws
    func getIntegrationStatus(integration: String) async throws -> IntegrationStatusDTO
    func submitOnboarding(_ payload: OnboardingDTO) async throws
    func registerDevice(token: String, platform: String, identity: String) async throws
    func unregisterDevice(token: String) async throws
    func healthCheck() async throws -> Bool
}
```

- Built on `URLSession`
- Base URL configurable via `ServerConfiguration(host: String, port: Int)`
- Health check used for connectivity detection before WebSocket connection

### AudioRecorder

```swift
protocol AudioRecorderProtocol {
    func start(format: AudioFormat) throws -> AsyncStream<Data>
    func stop()
    var isRecording: Bool { get }
}

enum AudioFormat {
    case aac   // Primary — iOS native, smaller payload
    case wav   // Fallback — guaranteed Whisper support
}
```

- Built on `AVAudioEngine`
- AAC encoding via `AVAudioConverter` (primary)
- WAV as fallback if AAC causes transcription issues
- Audio session configuration (`.playAndRecord`, `.defaultToSpeaker`) handled here
- Interruption handling (phone calls, Siri) via `AVAudioSession` notifications
- Route change handling (Bluetooth connect/disconnect)
- Microphone permission request is NOT in AlfredKit — it's in the app's `AudioService`

### AudioPlayer

```swift
protocol AudioPlayerProtocol {
    func play(_ data: Data) async
    func stop()
    var isPlaying: Bool { get }
}
```

- Plays WAV audio (base64-decoded from server responses)
- Built on `AVAudioPlayer`
- Queue support for sequential playback of notification audio

### DTOs

Codable structs matching the server's JSON format exactly:

```swift
struct TextMessageDTO: Codable       // { type, content, identity, channel, session_id? }
struct AudioMessageDTO: Codable      // { type, content, identity, channel, format? }
struct ServerResponseDTO: Codable    // { type, text, session_id, audio? }
struct SessionDTO: Codable           // { type, session_id }
struct NotificationDTO: Codable      // { type, title, body, urgency }
struct VoiceNotificationDTO: Codable // { type, title, audio }
struct ErrorDTO: Codable             // { type, text, session_id }
struct IntegrationDTO: Codable       // { name, description, configured, schema }
struct OnboardingDTO: Codable        // { wake_time, work_address, dietary_restrictions,
                                     //   proactivity_level, guest_controls }
struct DeviceRegistrationDTO: Codable // { device_token, platform, identity }
```

---

## Domain Layer

Lives in `App/Alfred/Domain/`. Pure Swift, no framework imports.

### Entities

```swift
struct Message: Identifiable {
    let id: UUID
    let role: Role              // .user, .alfred
    let content: String
    let timestamp: Date
    let audio: Data?
    enum Role { case user, alfred }
}

struct Conversation: Identifiable {
    let id: UUID
    var messages: [Message]
    let createdAt: Date
}

struct Notification: Identifiable {
    let id: UUID
    let title: String
    let body: String?               // nil for voice-only notifications
    let urgency: Urgency
    let timestamp: Date
    let audio: Data?                // Only present on voiceNotification type
    enum Urgency { case informational, important, urgent }
}

struct Integration: Identifiable {
    let name: String            // also the id
    let description: String
    let configured: Bool
    let schema: [CredentialField]
}

struct CredentialField {
    let key: String
    let label: String
    let type: FieldType         // .text, .password
    let required: Bool
    enum FieldType { case text, password }
}

struct UserPreferences {
    var wakeTime: String?
    var workAddress: String?
    var dietaryRestrictions: String?
    var proactivityLevel: ProactivityLevel
    var guestControls: [String]     // Flat list matching server format: ["Lighting control", "Media playback", ...]
    enum ProactivityLevel { case opinionated, moderate, conservative }
}

struct ServerConfig {
    var host: String            // Tailscale IP
    var port: Int               // Default 8081
}
```

### Repository Protocols

```swift
protocol ChatRepositoryProtocol {
    func connect() async throws
    func disconnect()
    func send(text: String) async throws -> Message
    func send(audioData: Data, format: AudioFormat) async throws -> Message
    var messages: AsyncStream<Message> { get }
    var connectionState: AsyncStream<ConnectionState> { get }
}

protocol NotificationRepositoryProtocol {
    var notifications: AsyncStream<Notification> { get }
    func registerDevice(token: Data) async throws
    func unregisterDevice() async throws
}

protocol IntegrationRepositoryProtocol {
    func getAll() async throws -> [Integration]
    func saveCredentials(integration: String, fields: [String: String]) async throws
    func deleteCredentials(integration: String) async throws
    func checkStatus(integration: String) async throws -> Bool
}

protocol OnboardingRepositoryProtocol {
    func submit(preferences: UserPreferences) async throws
    var isComplete: Bool { get }
}

protocol SessionRepositoryProtocol {
    func saveSessionId(_ id: String)
    func restoreSessionId() -> String?
    func clearSession()
    func saveServerConfig(_ config: ServerConfig)
    func restoreServerConfig() -> ServerConfig?
}

protocol MessageStoreProtocol {
    func save(_ message: Message, conversationId: UUID) async throws
    func fetchMessages(conversationId: UUID) async throws -> [Message]
    func fetchConversations() async throws -> [Conversation]
    func deleteConversation(_ id: UUID) async throws
}
```

### Use Cases

```swift
// Chat
class ConnectUseCase(chatRepo, sessionRepo)
    // Restores session ID from Keychain, connects, handles reconnect banner
    func execute() async throws

class SendTextMessageUseCase(chatRepo, messageStore)
    // Sends message, persists to SwiftData, returns domain Message
    func execute(text: String) async throws -> Message

class SendVoiceMessageUseCase(chatRepo, messageStore)
    // Sends audio, persists transcribed response, returns domain Message
    func execute(audioData: Data, format: AudioFormat) async throws -> Message

class ObserveMessagesUseCase(chatRepo)
    // Exposes message stream from repository
    func execute() -> AsyncStream<Message>

// Notifications
class ObserveNotificationsUseCase(notificationRepo)
    func execute() -> AsyncStream<Notification>

class RegisterForPushUseCase(notificationRepo)
    func execute(deviceToken: Data) async throws

// Onboarding
class SubmitOnboardingUseCase(onboardingRepo)
    func execute(preferences: UserPreferences) async throws

// Integrations
class ManageIntegrationsUseCase(integrationRepo)
    func getAll() async throws -> [Integration]
    func saveCredentials(integration: String, fields: [String: String]) async throws
    func deleteCredentials(integration: String) async throws
    func checkStatus(integration: String) async throws -> Bool
```

---

## Data Layer

Lives in `App/Alfred/Data/`. Imports both Domain and AlfredKit.

### Repository Implementations

**ChatRepositoryImpl:**
- Wraps `WebSocketClient`
- Filters `ServerMessage` stream: `.response` and `.transcription` → maps to `Message` entities
- Manages audio recording lifecycle via `AudioRecorder`
- Plays response audio via `AudioPlayer`
- Injects session ID from `SessionRepository` on connect

**NotificationRepositoryImpl:**
- Filters `ServerMessage` stream: `.notification` and `.voiceNotification` → maps to `Notification` entities
- Handles APNs device token registration via `RESTClient`
- Shares the same `WebSocketClient` instance as `ChatRepositoryImpl` (singleton from DI)

**IntegrationRepositoryImpl:**
- Straight pass-through to `RESTClient` with DTO → Entity mapping

**OnboardingRepositoryImpl:**
- Maps `UserPreferences` → `OnboardingDTO`, calls `RESTClient`
- Tracks completion flag in `UserDefaults`

**SessionRepositoryImpl:**
- Persists session ID and server config in iOS Keychain via `KeychainStore`

**MessageStoreImpl:**
- SwiftData-backed local message persistence
- Stores `Message` and `Conversation` entities
- Queried on app launch to restore conversation history

### Mappers

One mapper per entity pair. Stateless, static methods:

```swift
MessageMapper.toDomain(ServerMessage) -> Message
NotificationMapper.toDomain(ServerMessage) -> Notification
IntegrationMapper.toDomain(IntegrationDTO) -> Integration
OnboardingMapper.toDTO(UserPreferences) -> OnboardingDTO
```

### Local Storage

```swift
// KeychainStore — sensitive data
KeychainStore.save(key: String, value: String)
KeychainStore.load(key: String) -> String?
KeychainStore.delete(key: String)
// Used for: session ID, server host/port

// SwiftData — message persistence
@Model class MessageRecord { id, role, content, timestamp, audioPath, conversationId }
@Model class ConversationRecord { id, createdAt }
```

---

## Presentation Layer

### App Structure

```
AlfredApp (entry point)
├── BiometricGate (Face ID / passcode challenge)
│   └── MainTabView
│       ├── ChatTab
│       │   └── ChatView + ChatViewModel
│       ├── NotificationsTab
│       │   └── NotificationsView + NotificationsViewModel
│       └── SettingsTab
│           └── SettingsView + SettingsViewModel
│               ├── ServerConfigView + ServerConfigViewModel
│               └── IntegrationsView (reuses SettingsViewModel)
└── OnboardingOverlay (full-screen, shown once)
    └── OnboardingFlow + OnboardingViewModel
```

### ViewModels

All ViewModels use `@Observable` (iOS 17+). Injected via `@Environment` from `AppContainer`.

**ChatViewModel:**
```swift
@Observable class ChatViewModel {
    var messages: [Message] = []
    var connectionState: ConnectionState = .disconnected
    var isRecording: Bool = false
    var isWaiting: Bool = false    // Typing indicator while awaiting response
    var inputText: String = ""

    func send()                    // Send text message
    func toggleRecording()         // Start/stop voice recording
    func reconnect()               // Manual reconnect
}
```

**NotificationsViewModel:**
```swift
@Observable class NotificationsViewModel {
    var notifications: [Notification] = []  // Grouped by date in view
    func playAudio(_ notification: Notification)
}
```

**OnboardingViewModel:**
```swift
@Observable class OnboardingViewModel {
    var currentStep: Int = 0       // Steps 0-5
    var preferences: UserPreferences = .default
    var integrations: [Integration] = []

    func next()
    func skip()
    func submit() async throws
}
```

**SettingsViewModel:**
```swift
@Observable class SettingsViewModel {
    var integrations: [Integration] = []
    var isFaceIDEnabled: Bool = true

    func loadIntegrations() async throws
    func saveCredentials(integration: String, fields: [String: String]) async throws
    func deleteCredentials(integration: String) async throws
    func checkStatus(integration: String) async throws -> Bool
}
```

**ServerConfigViewModel:**
```swift
@Observable class ServerConfigViewModel {
    var host: String = ""          // Tailscale IP
    var port: Int = 8081
    var isReachable: Bool = false

    func save()                    // Persist to Keychain
    func testConnection() async    // GET /health
}
```

### Key Views

**ChatView:**
- `ScrollViewReader` + `LazyVStack` for message list
- Auto-scroll to bottom on new messages
- Input bar: text field + send button + mic toggle
- Mic: tap-and-hold to record, release to send
- Waiting indicator (animated dots) shown while `isWaiting == true`
- Connection status indicator in navigation bar
- Empty state prompts first message

**NotificationsView:**
- `List` grouped by date section headers
- Each row: urgency icon (SF Symbol), title, body, relative timestamp
- Tap notification with audio to play it
- Swipe to dismiss
- Badge count on tab for unread

**OnboardingFlow:**
- Full-screen overlay, matches web PWA 6-step flow
- Step 0: Welcome
- Step 1: Basic preferences (wake time, work address, dietary)
- Step 2: Proactivity level (segmented control)
- Step 3: Guest mode access (toggles)
- Step 4: Integration credentials (dynamic from server)
- Step 5: Completion
- Skip button on each step
- Progress indicator (step dots)

**SettingsView:**
- `NavigationStack` with `List` sections
- Server Connection: host, port, connection status, test button
- Integrations: dynamic list from server, each shows name + configured badge
- Tap integration → credential form sheet
- App: Face ID toggle, about/version

**BiometricGate:**
- Shown at app launch before any content
- Uses `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` — Face ID with passcode fallback
- Bypass in debug builds via compile flag

### Design

- Native iOS aesthetic: SF Pro, SF Symbols, standard UIKit/SwiftUI components
- Follow Apple Human Interface Guidelines
- System colors (adaptive light/dark mode)
- Standard iOS tab bar, navigation bars, list styles
- No custom fonts, no branded visual flourishes in v1
- `Info.plist` requires `NSAllowsArbitraryLoads = YES` for App Transport Security (Tailscale IPs are plain HTTP over VPN tunnel — `NSAllowsLocalNetworking` only covers Bonjour/mDNS, not routed VPN traffic)

---

## Push Notifications (APNs)

### iOS Side

```swift
// AlfredApp.swift — AppDelegate adapter
UNUserNotificationCenter.requestAuthorization([.alert, .sound, .badge])
UIApplication.registerForRemoteNotifications()

// On token received:
func application(didRegisterForRemoteNotificationsWithDeviceToken:)
    → NotificationRepository.registerDevice(token:)
    → POST /api/devices/register

// Foreground: route to NotificationsViewModel via UNUserNotificationCenterDelegate
// Background: system displays natively
```

Critical alert entitlement (`.criticalAlert`) — apply via developer.apple.com if desired for urgent notifications that bypass DND. Optional for v1.

### Server Side

See Server-Side Changes section.

---

## Background Behavior

iOS aggressively manages app lifecycle. The design accounts for this:

| App State | WebSocket | Notifications | Audio |
|---|---|---|---|
| Foreground | Active | Via WebSocket stream | Recording + playback available |
| Background (0-30s) | Alive but unreliable | Via WebSocket (may miss) | Stops |
| Suspended | Dead | Via APNs only | Not available |
| Terminated | Dead | Via APNs only | Not available |

**Key implications:**
- APNs is the primary notification delivery channel, not a fallback
- WebSocket notifications are a bonus when the app is foregrounded
- On app resume: reconnect WebSocket, show banner if messages may have been missed during disconnect
- No background audio recording (iOS limitation, acceptable)
- No background fetch needed for v1

**Reconnection flow:**
1. App enters foreground → attempt WebSocket reconnect with persisted session ID
2. If session expired (server returns new session ID) → show "Session expired" banner, start fresh conversation
3. If reconnect succeeds with same session → resume normally
4. Known limitation: messages/responses in-flight during disconnect are lost. Documented, not solved in v1.

---

## Wire Format Contract

Exact JSON shapes for every WebSocket message type. These are the contract between AlfredKit DTOs and the server.

### Client → Server

```json
// Text message
{"type": "text", "content": "What's the weather?", "identity": "sir", "channel": "ios", "session_id": "uuid-or-null"}

// Audio message (data URL encoding, matching web PWA convention)
{"type": "audio", "content": "data:audio/aac;base64,AAAA...", "identity": "sir", "channel": "ios"}
```

### Server → Client

```json
// Session assignment (first message after connect)
{"type": "session", "session_id": "550e8400-e29b-41d4-a716-446655440000"}

// Text + optional audio response
{"type": "response", "text": "It's 72°F and sunny.", "session_id": "...", "audio": "base64-wav-or-null"}

// Voice transcription (intermediate, before full response)
{"type": "transcription", "text": "What's the weather", "session_id": "..."}

// Proactive notification (text only — no audio field)
{"type": "notification", "title": "Weather Alert", "body": "Rain expected at 3pm", "urgency": "important"}

// Voice notification (audio only)
{"type": "voice_notification", "title": "Trigger Fired", "audio": "base64-wav"}

// Error
{"type": "error", "text": "Failed to process request", "session_id": "..."}
```

### REST Endpoints

| Method | Path | Request Body | Response | Notes |
|---|---|---|---|---|
| GET | `/health` | — | `{"status": "ok", "service": "web-channel"}` | 200 = reachable |
| GET | `/api/integrations` | — | `[{name, description, configured, schema: [{key, label, type, required}]}]` | |
| PUT | `/api/integrations/{name}/credentials` | `{field: value, ...}` | 200 or 403/422 | Requires trusted network |
| DELETE | `/api/integrations/{name}/credentials` | — | 200 or 403 | Requires trusted network |
| GET | `/api/integrations/{name}/status` | — | `{"healthy": bool, "message": "..."}` | |
| POST | `/api/onboarding` | `{wake_time, work_address, dietary_restrictions, proactivity_level, guest_controls}` | 200 | |
| POST | `/api/devices/register` | `{device_token, platform, identity}` | 200 | New endpoint |
| DELETE | `/api/devices/register` | `{device_token}` | 200 | New endpoint |

### Error Handling

REST endpoints return standard HTTP status codes:
- `200` — success
- `403` — request from untrusted network (not localhost/Tailscale)
- `404` — integration not found
- `422` — validation error (missing required fields)
- `500` — server error

The `RESTClient` maps these to typed Swift errors: `AlfredAPIError.forbidden`, `.notFound`, `.validationError(detail:)`, `.serverError`.

---

## Server-Side Changes

All changes in the `alfred/` monorepo (Python).

### 1. Add `"ios"` Channel and Accept `channel` from Client

**bus/schemas/events.py:** Add `"ios"` to the `channel` Literal on `UserRequest` and `AlfredResponse`.

**core/channels/web_server.py:** The WebSocket handler currently hardcodes `channel="web_pwa"` when constructing `UserRequest`. Change it to read the `channel` field from the client's JSON message. If absent, default to `"web_pwa"` for backward compatibility. The iOS client sends `channel: "ios"` in every message. This enables channel-based routing (e.g., APNs for iOS, WebSocket for web).

### 2. Replace `require_localhost` with `require_trusted_network` (core/channels/web_server.py)

Replace the localhost-only guard on credential endpoints with a check that accepts:
- `127.0.0.1` / `::1` (localhost)
- `100.64.0.0/10` (Tailscale CGNAT range)

Applied to `PUT /api/integrations/{name}/credentials` and `DELETE /api/integrations/{name}/credentials`.

### 3. Multi-Format Audio Intake (core/channels/web_server.py)

Current: only accepts `data:audio/webm;base64,...`

Changes needed across three files:

1. **core/channels/web_server.py `_decode_audio()`:** Currently discards MIME type from the data URL. Change to extract and return both the raw bytes and the audio format (e.g., `"webm"`, `"aac"`, `"wav"`, `"m4a"`). If the client sends a `format` field in the JSON message, prefer that over parsing the data URL.

2. **core/channels/web_server.py WebSocket handler:** Pass the extracted format through to the STT call.

3. **core/voice/stt.py `WhisperSTT.transcribe()`:** Currently hardcodes `suffix=".wav"` for the tempfile. Change to accept a `format` parameter and use the correct suffix (e.g., `.aac`, `.m4a`, `.webm`). faster-whisper uses ffmpeg under the hood, which uses the file extension as a format hint — wrong extension causes decode failures.

iOS audio content is sent as a data URL string matching existing protocol: `data:audio/aac;base64,...` (AAC primary) or `data:audio/wav;base64,...` (WAV fallback).

Test AAC/M4A transcription quality during implementation. Fallback logic: the iOS app attempts AAC first. If the server returns a transcription error or empty transcription for an AAC payload, the app automatically retries with WAV for that message and persists the format preference for future recordings. This is client-side logic in `AudioRecorder`, not a server negotiation.

### 4. APNs Delivery Adapter (core/notifications/adapters/apns.py) — HIGHEST PRIORITY

New `APNsChannelAdapter` implementing the existing adapter protocol:
- Reads device tokens from Redis hash `alfred:push:devices`
- Sends push notifications via APNs HTTP/2 API (httpx with h2 support or PyAPNs2)
- Registered in the channels process `ChannelRegistry`
- APNs `.p8` key stored via existing Secrets Manager (Keyring)

Urgency mapping to APNs payload:
```json
// informational
{"aps": {"alert": {"title": "...", "body": "..."}, "sound": null, "interruption-level": "passive"}}

// important
{"aps": {"alert": {"title": "...", "body": "..."}, "sound": "default", "interruption-level": "active"}}

// urgent (with critical alert entitlement)
{"aps": {"alert": {"title": "...", "body": "..."}, "sound": {"critical": 1, "name": "default", "volume": 1.0}, "interruption-level": "critical"}}
```

APNs HTTP/2 headers: `apns-priority: 5` (informational) or `10` (important/urgent), `apns-push-type: alert`.

**Deduplication with WebSocket:** When the iOS app is foregrounded, notifications arrive via both WebSocket stream AND APNs simultaneously. The iOS app handles this via `UNUserNotificationCenterDelegate.willPresent` — when foregrounded, suppress the APNs banner display and rely on the WebSocket stream to update the `NotificationsViewModel`. When backgrounded/suspended, the WebSocket is dead so only APNs delivers, with no duplication. Each notification includes an `id` field for deduplication matching.

### 5. Device Registration Endpoint (core/channels/web_server.py)

```
POST /api/devices/register
Body: { "device_token": "hex...", "platform": "ios", "identity": "sir" }

DELETE /api/devices/register
Body: { "device_token": "hex..." }
```

**Redis data structure:** Hash keyed by device token, value is JSON:
```
HSET alfred:push:devices "<device_token_hex>" '{"platform":"ios","identity":"sir","registered_at":"2026-04-03T12:00:00Z"}'
```

The APNs adapter iterates all hash entries to find tokens for a given identity. For a single-user system this is a full scan of 1-2 entries — no performance concern.

No auth guard (behind Tailscale). Same trust model as existing endpoints.

### 6. Add Redis Key Constant (shared/streams.py)

Add `DEVICE_TOKENS_KEY = "alfred:push:devices"` to the single source of truth for Redis keys.

---

## Testing Strategy

### AlfredKit (Swift Package tests)

- WebSocket client: mock `URLSessionWebSocketTask` delegate, verify message encoding/decoding, reconnect behavior
- REST client: mock `URLProtocol`, verify request shapes match server expectations
- DTO round-trip: encode → decode all DTOs, verify JSON matches server format
- Audio recorder: verify AAC/WAV output format (integration test with real AVAudioEngine where possible)

### Domain (unit tests — pure Swift, fast)

- Use case tests with mock repository implementations
- Verify business rules (e.g., can't send while disconnected)
- Entity construction and validation

### Data (repository + mapper tests)

- Repository tests with mocked AlfredKit protocols
- Mapper tests: DTO → Entity for every type, including edge cases (null audio, missing fields)
- KeychainStore: write/read/delete cycle
- SwiftData MessageStore: CRUD operations

### Presentation (ViewModel + snapshot tests)

- ViewModel state transitions: loading → connected → sending → waiting → received
- Error state handling: connection failure, send failure, reconnect
- `swift-snapshot-testing` for key views:
  - ChatView (empty, with messages, with waiting indicator)
  - OnboardingFlow (each step)
  - SettingsView (with integrations loaded)
  - NotificationsView (with items, empty)
- Snapshot on iPhone 16 Pro and iPhone SE sizes

### Server-Side (pytest)

- APNs adapter: mocked HTTP client, verify payload format matches APNs spec
- Multi-format audio: send AAC, m4a, wav → verify Whisper receives correct bytes
- Device registration: POST/DELETE, verify Redis hash operations
- `require_trusted_network`: test localhost, Tailscale IP, and external IP rejection

---

## Tooling

### Required (install before starting)

| Tool | Install | Purpose |
|---|---|---|
| XcodeGen | `brew install xcodegen` | Generate .xcodeproj from project.yml |
| XcodeBuildMCP | `brew tap getsentry/xcodebuildmcp && brew install xcodebuildmcp` | Build, test, run simulator from CLI |
| swift-snapshot-testing | SPM test dependency | Visual regression testing |
| Xcode 26+ | Already installed | Build toolchain, simulators |

### Optional (defer)

| Tool | Purpose | When to add |
|---|---|---|
| Fastlane | Automated TestFlight uploads | When manual uploads feel tedious |
| asc-mcp | TestFlight build management from CLI | When you want autonomous deploy |
| ios-preview-mcp | Isolated SwiftUI view rendering | For visual iteration on components |

### Dev Loop (Claude Code)

```
1. Edit Swift code / project.yml
2. xcodegen generate
3. XcodeBuildMCP: build_sim
4. XcodeBuildMCP: build_run_sim
5. XcodeBuildMCP: screenshot / snapshot_ui
6. XcodeBuildMCP: test_sim
7. Fix, repeat
```

### Deploy Loop (v1 — manual)

```
1. xcodebuild archive -scheme Alfred -archivePath build/Alfred.xcarchive
2. xcodebuild -exportArchive -archivePath build/Alfred.xcarchive -exportPath build/ -exportOptionsPlist ExportOptions.plist
3. xcrun altool --upload-app -f build/Alfred.ipa -t ios --apiKey $KEY_ID --apiIssuer $ISSUER_ID
4. Wait for TestFlight processing, install on device
```

### Work Split

| Claude Code | You |
|---|---|
| All Swift code, project.yml, Package.swift | Initial Xcode team/signing setup |
| Architecture, ViewModels, Views, tests | Visual QA on simulator/device |
| Server-side Python changes | Apple Developer portal setup (APNs key, ASC API key) |
| Build + test via XcodeBuildMCP | TestFlight install + real-device testing |
| Snapshot test maintenance | Critical alert entitlement request (optional) |

---

## Known Limitations (v1)

1. **No custom auth** — Tailscale is the trust boundary. Anyone on the Tailnet can claim `identity: "sir"`.
2. **Session restore race condition** — Responses in-flight during WebSocket disconnect are lost. UI shows reconnection banner.
3. **No offline mode** — All features require network connectivity to Alfred server.
4. **No streaming responses** — Full response arrives at once (no token-by-token streaming).
5. **No conversation sync** — Local SwiftData history is device-only. Server has no message history API.
6. **Credential management requires Tailscale** — `require_trusted_network` checks for Tailscale CGNAT range. No access from arbitrary networks.

---

## Future (post-v1)

- Siri Shortcuts / App Intents ("Hey Siri, ask Alfred...")
- Home screen + lock screen widgets (weather, next trigger, quick actions)
- Live Activities for active triggers
- WebAuthn passkey authentication (unblocks web PWA too)
- Notification Service Extension for rich notifications
- watchOS companion (AlfredKit reuse)
- macOS menu bar app (AlfredKit reuse)
- Streaming TTS playback
- Background fetch for notification history sync
