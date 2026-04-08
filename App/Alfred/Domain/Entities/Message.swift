import Foundation

struct Message: Identifiable, Sendable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    let audio: Data?

    enum Role: Sendable {
        case user
        case alfred
    }
}
