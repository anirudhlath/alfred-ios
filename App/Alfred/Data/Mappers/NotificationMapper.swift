import Foundation
import AlfredKit

enum NotificationMapper {
    static func toDomain(from serverMessage: ServerMessage) -> AppNotification? {
        switch serverMessage {
        case .notification(let title, let body, let urgency):
            return AppNotification(
                id: UUID(),
                title: title,
                body: body,
                urgency: mapUrgency(urgency),
                timestamp: Date(),
                audio: nil
            )
        case .voiceNotification(let title, let audio):
            return AppNotification(
                id: UUID(),
                title: title,
                body: nil,
                urgency: .important,
                timestamp: Date(),
                audio: audio
            )
        default:
            return nil
        }
    }

    private static func mapUrgency(_ value: String) -> AppNotification.Urgency {
        switch value {
        case "urgent": return .urgent
        case "important": return .important
        default: return .informational
        }
    }
}
