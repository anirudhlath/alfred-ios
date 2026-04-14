import Foundation
import AlfredKit

final class NotificationRepositoryImpl: NotificationRepositoryProtocol, @unchecked Sendable {
    private let webSocketClient: any WebSocketClientProtocol
    private let restClient: any RESTClientProtocol
    private var deviceTokenHex: String?

    var notifications: AsyncStream<AppNotification> {
        AsyncStream { continuation in
            Task {
                for await serverMsg in webSocketClient.messages {
                    if let notification = NotificationMapper.toDomain(from: serverMsg) {
                        continuation.yield(notification)
                    }
                }
                continuation.finish()
            }
        }
    }

    var rawMessages: AsyncStream<ServerMessage> {
        AsyncStream { continuation in
            Task {
                for await serverMsg in webSocketClient.messages {
                    switch serverMsg {
                    case .notification, .voiceNotification:
                        continuation.yield(serverMsg)
                    default:
                        break
                    }
                }
                continuation.finish()
            }
        }
    }

    init(webSocketClient: any WebSocketClientProtocol, restClient: any RESTClientProtocol) {
        self.webSocketClient = webSocketClient
        self.restClient = restClient
    }

    func registerDevice(token: Data) async throws {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        self.deviceTokenHex = hex
        try await restClient.registerDevice(token: hex, platform: "ios", identity: "sir")
    }

    func unregisterDevice() async throws {
        guard let hex = deviceTokenHex else { return }
        try await restClient.unregisterDevice(token: hex)
        self.deviceTokenHex = nil
    }
}
