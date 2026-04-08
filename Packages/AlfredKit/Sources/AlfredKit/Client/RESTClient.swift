import Foundation

/// Protocol for the Alfred REST API client.
public protocol RESTClientProtocol: Sendable {
    func healthCheck() async -> Bool
    func getIntegrations() async throws -> [IntegrationDTO]
    func saveCredentials(integration: String, fields: [String: String]) async throws
    func deleteCredentials(integration: String) async throws
    func getIntegrationStatus(integration: String) async throws -> IntegrationStatusDTO
    func submitOnboarding(_ payload: OnboardingDTO) async throws
    func registerDevice(token: String, platform: String, identity: String) async throws
    func unregisterDevice(token: String) async throws
}

/// REST client for the Alfred web channel server.
public final class RESTClient: RESTClientProtocol, @unchecked Sendable {
    private let configuration: ServerConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(configuration: ServerConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func healthCheck() async -> Bool {
        let url = configuration.baseURL.appendingPathComponent("health")
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    public func getIntegrations() async throws -> [IntegrationDTO] {
        let url = configuration.baseURL.appendingPathComponent("api/integrations")
        let (data, response) = try await session.data(from: url)
        try checkResponse(response)
        return try decoder.decode([IntegrationDTO].self, from: data)
    }

    public func saveCredentials(integration: String, fields: [String: String]) async throws {
        let url = configuration.baseURL.appendingPathComponent("api/integrations/\(integration)/credentials")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(fields)
        let (_, response) = try await session.data(for: request)
        try checkResponse(response)
    }

    public func deleteCredentials(integration: String) async throws {
        let url = configuration.baseURL.appendingPathComponent("api/integrations/\(integration)/credentials")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: request)
        try checkResponse(response)
    }

    public func getIntegrationStatus(integration: String) async throws -> IntegrationStatusDTO {
        let url = configuration.baseURL.appendingPathComponent("api/integrations/\(integration)/status")
        let (data, response) = try await session.data(from: url)
        try checkResponse(response)
        return try decoder.decode(IntegrationStatusDTO.self, from: data)
    }

    public func submitOnboarding(_ payload: OnboardingDTO) async throws {
        let url = configuration.baseURL.appendingPathComponent("api/onboarding")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)
        let (_, response) = try await session.data(for: request)
        try checkResponse(response)
    }

    public func registerDevice(token: String, platform: String, identity: String) async throws {
        let url = configuration.baseURL.appendingPathComponent("api/devices/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let dto = DeviceRegistrationDTO(deviceToken: token, platform: platform, identity: identity)
        request.httpBody = try encoder.encode(dto)
        let (_, response) = try await session.data(for: request)
        try checkResponse(response)
    }

    public func unregisterDevice(token: String) async throws {
        let url = configuration.baseURL.appendingPathComponent("api/devices/register")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let dto = DeviceUnregistrationDTO(deviceToken: token)
        request.httpBody = try encoder.encode(dto)
        let (_, response) = try await session.data(for: request)
        try checkResponse(response)
    }

    private func checkResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300: return
        case 403: throw AlfredAPIError.forbidden
        case 404: throw AlfredAPIError.notFound
        case 422: throw AlfredAPIError.validationError(detail: "Validation failed")
        default: throw AlfredAPIError.serverError(statusCode: http.statusCode)
        }
    }
}
