import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    var notificationService: NotificationService?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        notificationService?.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Push not available (e.g., simulator)
    }
}

@main
struct AlfredApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var container = AppContainer()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboarding_complete")

    var body: some Scene {
        WindowGroup {
            BiometricGateView {
                MainTabView()
            }
            .environment(container)
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingFlowView(isPresented: $showOnboarding)
                    .environment(container)
            }
            .task {
                try? container.audioService.configureAudioSession()
                container.startNotificationObservation()
                let notificationService = NotificationService()
                notificationService.configure(with: container)
                appDelegate.notificationService = notificationService
                await notificationService.requestAuthorization()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                container.chatRepository.disconnect()
            case .active:
                Task {
                    try? await container.connectUseCase.execute()
                }
            default:
                break
            }
        }
    }
}
