import Foundation

final class RegisterForPushUseCase: Sendable {
    private let notificationRepo: any NotificationRepositoryProtocol

    init(notificationRepo: any NotificationRepositoryProtocol) {
        self.notificationRepo = notificationRepo
    }

    func execute(deviceToken: Data) async throws {
        try await notificationRepo.registerDevice(token: deviceToken)
    }
}
