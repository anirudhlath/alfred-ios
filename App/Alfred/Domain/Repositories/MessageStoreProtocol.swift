import Foundation

protocol MessageStoreProtocol: Sendable {
    func save(_ message: Message, conversationId: UUID) async throws
    func fetchMessages(conversationId: UUID) async throws -> [Message]
    func fetchConversations() async throws -> [Conversation]
    func createConversation(id: UUID) async throws
    func deleteConversation(_ id: UUID) async throws
}

struct Conversation: Identifiable, Sendable {
    let id: UUID
    var messages: [Message]
    let createdAt: Date
}
