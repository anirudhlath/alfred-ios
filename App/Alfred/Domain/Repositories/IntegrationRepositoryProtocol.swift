protocol IntegrationRepositoryProtocol: Sendable {
    func getAll() async throws -> [Integration]
    func saveCredentials(integration: String, fields: [String: String]) async throws
    func deleteCredentials(integration: String) async throws
    func checkStatus(integration: String) async throws -> Bool
}
