import Foundation

final class ManageIntegrationsUseCase: Sendable {
    private let integrationRepo: any IntegrationRepositoryProtocol

    init(integrationRepo: any IntegrationRepositoryProtocol) {
        self.integrationRepo = integrationRepo
    }

    func getAll() async throws -> [Integration] {
        try await integrationRepo.getAll()
    }

    func saveCredentials(integration: String, fields: [String: String]) async throws {
        try await integrationRepo.saveCredentials(integration: integration, fields: fields)
    }

    func deleteCredentials(integration: String) async throws {
        try await integrationRepo.deleteCredentials(integration: integration)
    }

    func checkStatus(integration: String) async throws -> Bool {
        try await integrationRepo.checkStatus(integration: integration)
    }
}
