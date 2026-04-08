import Foundation

/// Typed errors from Alfred REST API.
public enum AlfredAPIError: Error, Sendable {
    case forbidden
    case notFound
    case validationError(detail: String)
    case serverError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
}
