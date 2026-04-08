import Foundation

final class SubmitOnboardingUseCase: Sendable {
    private let onboardingRepo: any OnboardingRepositoryProtocol

    init(onboardingRepo: any OnboardingRepositoryProtocol) {
        self.onboardingRepo = onboardingRepo
    }

    func execute(preferences: UserPreferences) async throws {
        try await onboardingRepo.submit(preferences: preferences)
    }
}
