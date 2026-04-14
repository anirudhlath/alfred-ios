import Foundation
import SwiftData

final class MessageStoreImpl: MessageStoreProtocol, @unchecked Sendable {
    private let container: ModelContainer

    init() {
        let schema = Schema([MessageRecord.self, ConversationRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        // swiftlint:disable force_try
        self.container = try! ModelContainer(for: schema, configurations: [config])
        // swiftlint:enable force_try
    }

    // For testing with in-memory store
    init(container: ModelContainer) {
        self.container = container
    }

    @MainActor
    func save(_ message: Message, conversationId: UUID) async throws {
        let context = container.mainContext
        let record = MessageRecord(
            id: message.id,
            role: message.role == .user ? "user" : "alfred",
            content: message.content,
            timestamp: message.timestamp,
            audioPath: nil,
            conversationId: conversationId
        )
        context.insert(record)
        try context.save()
    }

    @MainActor
    func fetchMessages(conversationId: UUID) async throws -> [Message] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<MessageRecord>(
            predicate: #Predicate { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let records = try context.fetch(descriptor)
        return records.map { record in
            Message(
                id: record.id,
                role: record.role == "user" ? .user : .alfred,
                content: record.content,
                timestamp: record.timestamp,
                audio: nil
            )
        }
    }

    @MainActor
    func createConversation(id: UUID) async throws {
        let context = container.mainContext
        let record = ConversationRecord(id: id, createdAt: Date())
        context.insert(record)
        try context.save()
    }

    @MainActor
    func fetchConversations() async throws -> [Conversation] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<ConversationRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let records = try context.fetch(descriptor)
        return records.map { record in
            Conversation(id: record.id, messages: [], createdAt: record.createdAt)
        }
    }

    @MainActor
    func deleteConversation(_ id: UUID) async throws {
        let context = container.mainContext
        // Delete messages
        let msgDescriptor = FetchDescriptor<MessageRecord>(
            predicate: #Predicate { $0.conversationId == id }
        )
        let messages = try context.fetch(msgDescriptor)
        for msg in messages { context.delete(msg) }
        // Delete conversation
        let convDescriptor = FetchDescriptor<ConversationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        let conversations = try context.fetch(convDescriptor)
        for conv in conversations { context.delete(conv) }
        try context.save()
    }
}
