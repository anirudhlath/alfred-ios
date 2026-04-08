import Foundation

/// Connection state for the chat WebSocket (domain-level, mirrors AlfredKit.ConnectionState).
enum AppConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected(sessionId: String)
}

enum AudioFormat: Sendable {
    case aac
    case wav
}

protocol ChatRepositoryProtocol: Sendable {
    func connect() async throws
    func disconnect()
    func send(text: String) async throws -> Message
    func send(audioData: Data, format: AudioFormat) async throws -> Message
    var messages: AsyncStream<Message> { get }
    var connectionState: AsyncStream<AppConnectionState> { get }
}
