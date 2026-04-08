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

    public let messages: AsyncStream<ServerMessage>
    public let connectionState: AsyncStream<ConnectionState>

    public init(session: URLSession = .shared) {
        var msgCont: AsyncStream<ServerMessage>.Continuation!
        let msgs = AsyncStream<ServerMessage> { msgCont = $0 }
        self.messages = msgs

        var stateCont: AsyncStream<ConnectionState>.Continuation!
        let states = AsyncStream<ConnectionState> { stateCont = $0 }
        self.connectionState = states

        self.state = WebSocketState(
            session: session,
            messagesContinuation: msgCont,
            stateContinuation: stateCont
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

    private let messagesContinuation: AsyncStream<ServerMessage>.Continuation
    private let stateContinuation: AsyncStream<ConnectionState>.Continuation

    init(
        session: URLSession,
        messagesContinuation: AsyncStream<ServerMessage>.Continuation,
        stateContinuation: AsyncStream<ConnectionState>.Continuation
    ) {
        self.session = session
        self.messagesContinuation = messagesContinuation
        self.stateContinuation = stateContinuation
    }

    func connect(to url: URL, sessionId: String?) {
        self.connectURL = url
        self.sessionId = sessionId
        self.shouldReconnect = true
        self.reconnectDelay = 1.0

        stateContinuation.yield(.connecting)
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
        stateContinuation.yield(.disconnected)
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
                            stateContinuation.yield(.connected(sessionId: sid))
                        }
                        messagesContinuation.yield(serverMsg)
                    } catch {
                        // Skip unparseable messages
                    }
                case .data:
                    break
                @unknown default:
                    break
                }
            } catch {
                stateContinuation.yield(.disconnected)
                if shouldReconnect {
                    await attemptReconnect()
                }
                return
            }
        }
    }

    private func attemptReconnect() async {
        guard shouldReconnect, let url = connectURL else { return }

        stateContinuation.yield(.connecting)
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
