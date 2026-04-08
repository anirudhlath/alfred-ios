import Foundation
import SwiftData

@Model
final class ConversationRecord {
    var id: UUID
    var createdAt: Date

    init(id: UUID, createdAt: Date) {
        self.id = id
        self.createdAt = createdAt
    }
}
