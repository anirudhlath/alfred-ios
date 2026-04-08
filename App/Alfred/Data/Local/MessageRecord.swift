import Foundation
import SwiftData

@Model
final class MessageRecord {
    var id: UUID
    var role: String
    var content: String
    var timestamp: Date
    var audioPath: String?
    var conversationId: UUID

    init(id: UUID, role: String, content: String, timestamp: Date, audioPath: String?, conversationId: UUID) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.audioPath = audioPath
        self.conversationId = conversationId
    }
}
