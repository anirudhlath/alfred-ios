import SwiftUI

@main
struct AlfredApp: App {
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
        }
    }
}
