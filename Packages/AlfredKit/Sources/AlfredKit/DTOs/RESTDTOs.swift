// Packages/AlfredKit/Sources/AlfredKit/DTOs/RESTDTOs.swift
import Foundation

/// Integration info from GET /api/integrations.
public struct IntegrationDTO: Codable, Sendable {
    public let name: String
    public let category: String?
    public let description: String?
    public let schema: IntegrationSchemaDTO
    public let configured: [String: Bool]

    public init(name: String, category: String? = nil, description: String? = nil, schema: IntegrationSchemaDTO, configured: [String: Bool]) {
        self.name = name
        self.category = category
        self.description = description
        self.schema = schema
        self.configured = configured
    }
}

public struct IntegrationSchemaDTO: Codable, Sendable {
    public let fields: [String: CredentialFieldDTO]

    public init(fields: [String: CredentialFieldDTO]) {
        self.fields = fields
    }
}

public struct CredentialFieldDTO: Codable, Sendable {
    public let label: String
    public let type: String
    public let required: Bool
    public let transient: Bool?

    public init(label: String, type: String, required: Bool, transient: Bool? = nil) {
        self.label = label
        self.type = type
        self.required = required
        self.transient = transient
    }
}

/// Health check response.
public struct HealthDTO: Codable, Sendable {
    public let status: String
    public let service: String

    public init(status: String, service: String) {
        self.status = status
        self.service = service
    }
}

/// Integration status response.
public struct IntegrationStatusDTO: Codable, Sendable {
    public let name: String
    public let healthy: Bool

    public init(name: String, healthy: Bool) {
        self.name = name
        self.healthy = healthy
    }
}

/// Generic status response from POST/PUT/DELETE endpoints.
public struct StatusResponseDTO: Codable, Sendable {
    public let status: String

    public init(status: String) {
        self.status = status
    }
}
