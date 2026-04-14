import Foundation
import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {
    var integrations: [Integration] = []
    var isLoading = false
    var pushNotificationsEnabled = true
    private var container: AppContainer?

    func configure(with container: AppContainer) {
        self.container = container
    }

    func clearSession() {
        guard let container else { return }
        container.sessionRepository.clearSession()
        Task {
            try? await container.connectUseCase.execute()
        }
    }

    func togglePushNotifications(enabled: Bool) {
        pushNotificationsEnabled = enabled
        guard let container else { return }
        Task {
            if enabled {
                await requestAndRegisterPush()
            } else {
                try? await container.notificationRepository.unregisterDevice()
            }
        }
    }

    private func requestAndRegisterPush() async {
        // Re-registering triggers APNs to send the token via AppDelegate,
        // which calls registerForPushUseCase automatically.
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func loadIntegrations() async {
        guard let container else { return }
        isLoading = true
        do {
            integrations = try await container.manageIntegrationsUseCase.getAll()
        } catch {
            // Silently fail — list stays empty
        }
        isLoading = false
    }

    func saveCredentials(integration: String, fields: [String: String]) async throws {
        guard let container else { return }
        try await container.manageIntegrationsUseCase.saveCredentials(
            integration: integration,
            fields: fields
        )
        await loadIntegrations()
    }

    func deleteCredentials(integration: String) async throws {
        guard let container else { return }
        try await container.manageIntegrationsUseCase.deleteCredentials(integration: integration)
        await loadIntegrations()
    }

    func checkStatus(integration: String) async throws -> Bool {
        guard let container else { return false }
        return try await container.manageIntegrationsUseCase.checkStatus(integration: integration)
    }
}
