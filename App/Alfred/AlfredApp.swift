import SwiftUI

@main
struct AlfredApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            BiometricGateView {
                MainTabView()
            }
            .environment(container)
        }
    }
}
