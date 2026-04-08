import Foundation
import AlfredKit

final class IntegrationRepositoryImpl: IntegrationRepositoryProtocol, Sendable {
    private let restClient: any RESTClientProtocol

    init(restClient: any RESTClientProtocol) {
        self.restClient = restClient
    }

    func getAll() async throws -> [Integration] {
        let dtos = try await restClient.getIntegrations()
        return dtos.map { IntegrationMapper.toDomain(from: $0) }
    }

    func saveCredentials(integration: String, fields: [String: String]) async throws {
        try await restClient.saveCredentials(integration: integration, fields: fields)
    }

    func deleteCredentials(integration: String) async throws {
        try await restClient.deleteCredentials(integration: integration)
    }

    func checkStatus(integration: String) async throws -> Bool {
        let status = try await restClient.getIntegrationStatus(integration: integration)
        return status.healthy
    }
}
