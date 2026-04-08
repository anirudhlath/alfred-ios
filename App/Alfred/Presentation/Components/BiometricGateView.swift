import SwiftUI

struct BiometricGateView<Content: View>: View {
    let content: () -> Content
    @State private var isUnlocked = false
    @State private var biometricService = BiometricService()

    var body: some View {
        Group {
            if isUnlocked {
                content()
            } else {
                lockedView
            }
        }
        .task {
            #if DEBUG
            // Bypass biometrics in debug/simulator
            isUnlocked = true
            #else
            isUnlocked = await biometricService.authenticate()
            #endif
        }
    }

    private var lockedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Alfred")
                .font(.largeTitle.bold())
            Text("Authenticate to continue")
                .foregroundStyle(.secondary)
            Button("Unlock") {
                Task {
                    isUnlocked = await biometricService.authenticate()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
