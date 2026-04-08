protocol OnboardingRepositoryProtocol: Sendable {
    func submit(preferences: UserPreferences) async throws
    var isComplete: Bool { get }
}
