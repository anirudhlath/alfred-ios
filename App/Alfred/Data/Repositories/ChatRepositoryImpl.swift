import Foundation
import AlfredKit

final class ChatRepositoryImpl: ChatRepositoryProtocol, @unchecked Sendable {
    private let webSocketClient: any WebSocketClientProtocol
    private let sessionRepository: any SessionRepositoryProtocol
    private let identity = "sir"

    var messages: AsyncStream<Message> {
        AsyncStream { continuation in
            Task {
                for await serverMsg in webSocketClient.messages {
                    if let message = MessageMapper.toDomain(from: serverMsg) {
                        continuation.yield(message)
                    }
                }
                continuation.finish()
            }
        }
    }

    var connectionState: AsyncStream<AppConnectionState> {
        AsyncStream { continuation in
            Task {
                for await state in webSocketClient.connectionState {
                    switch state {
                    case .disconnected:
                        continuation.yield(.disconnected)
                    case .connecting:
                        continuation.yield(.connecting)
                    case .connected(let sessionId):
                        self.sessionRepository.saveSessionId(sessionId)
                        continuation.yield(.connected(sessionId: sessionId))
                    }
                }
                continuation.finish()
            }
        }
    }

    init(webSocketClient: any WebSocketClientProtocol, sessionRepository: any SessionRepositoryProtocol) {
        self.webSocketClient = webSocketClient
        self.sessionRepository = sessionRepository
    }

    func connect() async throws {
        let config = sessionRepository.restoreServerConfig() ?? ServerConfig.default
        let serverConfig = ServerConfiguration(host: config.host, port: config.port)
        let sessionId = sessionRepository.restoreSessionId()
        try await webSocketClient.connect(to: serverConfig.webSocketURL, sessionId: sessionId)
    }

    func disconnect() {
        webSocketClient.disconnect()
    }

    func send(text: String) async throws -> Message {
        let clientMsg = ClientMessage.text(content: text, identity: identity)
        try await webSocketClient.send(clientMsg)
        return Message(id: UUID(), role: .user, content: text, timestamp: Date(), audio: nil)
    }

    func send(audioData: Data, format: AudioFormat) async throws -> Message {
        let mimeType = format == .aac ? "audio/aac" : "audio/wav"
        let clientMsg = ClientMessage.audio(data: audioData, mimeType: mimeType, identity: identity)
        try await webSocketClient.send(clientMsg)
        return Message(id: UUID(), role: .user, content: "", timestamp: Date(), audio: audioData)
    }
}
