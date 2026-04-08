import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private var container: AppContainer?

    func configure(with container: AppContainer) {
        self.container = container
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {}
    }

    func handleDeviceToken(_ token: Data) {
        guard let container else { return }
        Task {
            try? await container.registerForPushUseCase.execute(deviceToken: token)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Foreground: suppress APNs display (deduplication — WebSocket stream handles it)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Don't show banner when app is foregrounded
        return []
    }

    // Handle tap on notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Could navigate to notifications tab — defer for v1
    }
}
