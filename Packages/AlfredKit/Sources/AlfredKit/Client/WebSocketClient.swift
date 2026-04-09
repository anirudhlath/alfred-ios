import Foundation

/// Protocol for the Alfred WebSocket client.
public protocol WebSocketClientProtocol: Sendable {
    func connect(to url: URL, sessionId: String?) async throws
    func disconnect()
    func send(_ message: ClientMessage) async throws
    var messages: AsyncStream<ServerMessage> { get }
    var connectionState: AsyncStream<ConnectionState> { get }
}

/// WebSocket client for the Alfred server.
///
/// Uses an internal actor to protect mutable state from data races under Swift 6
/// strict concurrency. Handles connection lifecycle, auto-reconnect with
/// exponential backoff, session ID management, and message parsing.
public final class WebSocketClient: WebSocketClientProtocol, Sendable {
    private let state: WebSocketState
    private let messageBroadcaster = Broadcaster<ServerMessage>()
    private let stateBroadcaster = Broadcaster<ConnectionState>()

    /// Each access returns a NEW subscriber stream — multiple consumers
    /// (chat + notifications) each get every message independently.
    public var messages: AsyncStream<ServerMessage> {
        messageBroadcaster.subscribe()
    }

    public var connectionState: AsyncStream<ConnectionState> {
        stateBroadcaster.subscribe()
    }

    public init(session: URLSession = .shared) {
        self.state = WebSocketState(
            session: session,
            messageBroadcaster: messageBroadcaster,
            stateBroadcaster: stateBroadcaster
        )
    }

    public func connect(to url: URL, sessionId: String?) async throws {
        await state.connect(to: url, sessionId: sessionId)
    }

    public func disconnect() {
        Task { await state.disconnect() }
    }

    public func send(_ message: ClientMessage) async throws {
        try await state.send(message)
    }
}

/// Actor encapsulating all mutable WebSocket state — eliminates data races.
actor WebSocketState {
    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    private var sessionId: String?
    private var shouldReconnect = false
    private var reconnectDelay: TimeInterval = 1.0
    private var connectURL: URL?

    private let messageBroadcaster: Broadcaster<ServerMessage>
    private let stateBroadcaster: Broadcaster<ConnectionState>

    init(
        session: URLSession,
        messageBroadcaster: Broadcaster<ServerMessage>,
        stateBroadcaster: Broadcaster<ConnectionState>
    ) {
        self.session = session
        self.messageBroadcaster = messageBroadcaster
        self.stateBroadcaster = stateBroadcaster
    }

    func connect(to url: URL, sessionId: String?) {
        self.connectURL = url
        self.sessionId = sessionId
        self.shouldReconnect = true
        self.reconnectDelay = 1.0

        stateBroadcaster.yield(.connecting)
        let wsTask = session.webSocketTask(with: url)
        self.task = wsTask
        wsTask.resume()

        Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    func disconnect() {
        shouldReconnect = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        stateBroadcaster.yield(.disconnected)
    }

    func send(_ message: ClientMessage) async throws {
        guard let task else {
            throw AlfredAPIError.networkError(
                NSError(domain: "AlfredKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected"])
            )
        }
        let data = try message.encode(sessionId: sessionId)
        try await task.send(.string(String(data: data, encoding: .utf8)!))
    }

    private func receiveLoop() async {
        guard let task else { return }

        while task.state == .running {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    guard let data = text.data(using: .utf8) else { continue }
                    do {
                        let serverMsg = try ServerMessage.parse(from: data)
                        if case .session(let sid) = serverMsg {
                            self.sessionId = sid
                            self.reconnectDelay = 1.0
                            stateBroadcaster.yield(.connected(sessionId: sid))
                        }
                        messageBroadcaster.yield(serverMsg)
                    } catch {
                        // Skip unparseable messages
                    }
                case .data:
                    break
                @unknown default:
                    break
                }
            } catch {
                stateBroadcaster.yield(.disconnected)
                if shouldReconnect {
                    await attemptReconnect()
                }
                return
            }
        }
    }

    private func attemptReconnect() async {
        guard shouldReconnect, let url = connectURL else { return }

        stateBroadcaster.yield(.connecting)
        try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))
        reconnectDelay = min(reconnectDelay * 2, 10.0)

        let wsTask = session.webSocketTask(with: url)
        self.task = wsTask
        wsTask.resume()

        Task { [weak self] in
            await self?.receiveLoop()
        }
    }
}
