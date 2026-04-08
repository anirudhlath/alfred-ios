import Foundation

final class ObserveNotificationsUseCase: Sendable {
    private let notificationRepo: any NotificationRepositoryProtocol

    init(notificationRepo: any NotificationRepositoryProtocol) {
        self.notificationRepo = notificationRepo
    }

    func execute() -> AsyncStream<AppNotification> {
        notificationRepo.notifications
    }
}
