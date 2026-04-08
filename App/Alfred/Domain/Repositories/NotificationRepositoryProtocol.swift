import Foundation

protocol NotificationRepositoryProtocol: Sendable {
    var notifications: AsyncStream<AppNotification> { get }
    func registerDevice(token: Data) async throws
    func unregisterDevice() async throws
}
