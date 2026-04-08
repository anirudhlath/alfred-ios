import Foundation
import AlfredKit

final class OnboardingRepositoryImpl: OnboardingRepositoryProtocol, Sendable {
    private let restClient: any RESTClientProtocol
    private static let completionKey = "onboarding_complete"

    var isComplete: Bool {
        UserDefaults.standard.bool(forKey: Self.completionKey)
    }

    init(restClient: any RESTClientProtocol) {
        self.restClient = restClient
    }

    func submit(preferences: UserPreferences) async throws {
        let dto = OnboardingMapper.toDTO(from: preferences)
        try await restClient.submitOnboarding(dto)
        UserDefaults.standard.set(true, forKey: Self.completionKey)
    }
}
