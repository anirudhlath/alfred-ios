import Foundation
import AlfredKit

enum MessageMapper {
    static func toDomain(from serverMessage: ServerMessage) -> Message? {
        switch serverMessage {
        case .response(let text, _, let audio):
            return Message(id: UUID(), role: .alfred, content: text, timestamp: Date(), audio: audio)
        case .transcription(let text, _):
            return Message(id: UUID(), role: .user, content: text, timestamp: Date(), audio: nil)
        default:
            return nil
        }
    }
}
