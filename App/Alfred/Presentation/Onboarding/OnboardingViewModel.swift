import Foundation
import SwiftUI

@Observable
@MainActor
final class OnboardingViewModel {
    var currentStep = 0
    var preferences = UserPreferences.default
    var integrations: [Integration] = []
    var isSubmitting = false
    private var container: AppContainer?

    let totalSteps = 6

    func configure(with container: AppContainer) {
        self.container = container
        Task {
            do {
                integrations = try await container.manageIntegrationsUseCase.getAll()
            } catch {}
        }
    }

    func next() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
        }
    }

    func skip() {
        next()
    }

    func submit() async {
        guard let container else { return }
        isSubmitting = true
        do {
            try await container.submitOnboardingUseCase.execute(preferences: preferences)
        } catch {}
        isSubmitting = false
    }
}
