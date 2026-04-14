import Foundation

import AlfredKit

protocol NotificationRepositoryProtocol: Sendable {
    var notifications: AsyncStream<AppNotification> { get }
    var rawMessages: AsyncStream<ServerMessage> { get }
    func registerDevice(token: Data) async throws
    func unregisterDevice() async throws
}
