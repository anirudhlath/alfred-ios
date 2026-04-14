import Foundation
import SwiftUI
import AlfredKit

@Observable
@MainActor
final class NotificationsViewModel {
    var playingNotificationId: UUID?
    private var container: AppContainer?

    /// Notifications are stored in AppContainer.pendingNotifications (eagerly captured).
    /// This computed property provides a direct binding.
    var notifications: [AppNotification] {
        get { container?.pendingNotifications ?? [] }
        set { container?.pendingNotifications = newValue }
    }

    func configure(with container: AppContainer) {
        guard self.container == nil else { return }
        self.container = container
    }

    func dismiss(_ notification: AppNotification) {
        notifications.removeAll { $0.id == notification.id }
    }

    func playAudio(_ notification: AppNotification) {
        guard let audio = notification.audio, let container else { return }
        playingNotificationId = notification.id
        Task {
            await container.audioService.player.play(audio)
            playingNotificationId = nil
        }
    }

    var groupedByDate: [(String, [AppNotification])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: notifications) { notification in
            calendar.startOfDay(for: notification.timestamp)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date, items) in
                (date.formatted(date: .abbreviated, time: .omitted), items)
            }
    }
}
