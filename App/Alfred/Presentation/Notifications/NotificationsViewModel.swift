import Foundation
import SwiftUI

@Observable
@MainActor
final class NotificationsViewModel {
    var notifications: [AppNotification] = []
    private var container: AppContainer?

    func configure(with container: AppContainer) {
        guard self.container == nil else { return }
        self.container = container

        Task {
            for await notification in container.observeNotificationsUseCase.execute() {
                notifications.insert(notification, at: 0)
            }
        }
    }

    func dismiss(_ notification: AppNotification) {
        notifications.removeAll { $0.id == notification.id }
    }

    var groupedByDate: [(String, [AppNotification])] {
        let grouped = Dictionary(grouping: notifications) { notification in
            notification.timestamp.formatted(date: .abbreviated, time: .omitted)
        }
        return grouped.sorted { $0.key > $1.key }
    }
}
