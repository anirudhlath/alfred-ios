import Foundation

struct AppNotification: Identifiable, Sendable {
    let id: UUID
    let title: String
    let body: String?
    let urgency: Urgency
    let timestamp: Date
    let audio: Data?

    enum Urgency: Sendable {
        case informational
        case important
        case urgent
    }
}
