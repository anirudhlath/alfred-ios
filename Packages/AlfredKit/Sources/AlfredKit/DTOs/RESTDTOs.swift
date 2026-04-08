// Packages/AlfredKit/Sources/AlfredKit/DTOs/RESTDTOs.swift
import Foundation

/// Integration info from GET /api/integrations.
public struct IntegrationDTO: Codable, Sendable {
    public let name: String
    public let category: String?
    public let description: String?
    public let schema: IntegrationSchemaDTO
    public let configured: [String: Bool]
}

public struct IntegrationSchemaDTO: Codable, Sendable {
    public let fields: [String: CredentialFieldDTO]
}

public struct CredentialFieldDTO: Codable, Sendable {
    public let label: String
    public let type: String
    public let required: Bool
    public let transient: Bool?
}

/// Health check response.
public struct HealthDTO: Codable, Sendable {
    public let status: String
    public let service: String
}

/// Integration status response.
public struct IntegrationStatusDTO: Codable, Sendable {
    public let name: String
    public let healthy: Bool
}

/// Generic status response from POST/PUT/DELETE endpoints.
public struct StatusResponseDTO: Codable, Sendable {
    public let status: String
}
