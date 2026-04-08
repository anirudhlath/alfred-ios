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
                let notificationService = NotificationService()
                notificationService.configure(with: container)
                appDelegate.notificationService = notificationService
                await notificationService.requestAuthorization()
            }
        }
    }
}
