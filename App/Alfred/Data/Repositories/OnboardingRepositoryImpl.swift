import Foundation
import AlfredKit

final class OnboardingRepositoryImpl: OnboardingRepositoryProtocol, Sendable {
    private let restClient: any RESTClientProtocol
    nonisolated(unsafe) private let defaults: UserDefaults
    private static let completionKey = "onboarding_complete"

    var isComplete: Bool {
        defaults.bool(forKey: Self.completionKey)
    }

    init(restClient: any RESTClientProtocol, defaults: UserDefaults = .standard) {
        self.restClient = restClient
        self.defaults = defaults
    }

    func submit(preferences: UserPreferences) async throws {
        let dto = OnboardingMapper.toDTO(from: preferences)
        try await restClient.submitOnboarding(dto)
        defaults.set(true, forKey: Self.completionKey)
    }
}
