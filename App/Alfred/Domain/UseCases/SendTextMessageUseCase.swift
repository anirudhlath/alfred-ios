import Foundation

final class SendTextMessageUseCase: Sendable {
    private let chatRepo: any ChatRepositoryProtocol
    private let messageStore: any MessageStoreProtocol

    init(chatRepo: any ChatRepositoryProtocol, messageStore: any MessageStoreProtocol) {
        self.chatRepo = chatRepo
        self.messageStore = messageStore
    }

    func execute(text: String, conversationId: UUID) async throws -> Message {
        let message = try await chatRepo.send(text: text)
        try await messageStore.save(message, conversationId: conversationId)
        return message
    }
}
