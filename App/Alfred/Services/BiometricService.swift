import Foundation
import LocalAuthentication

@MainActor
final class BiometricService {
    func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Authenticate to access Alfred"
            )
        } catch {
            return false
        }
    }
}
