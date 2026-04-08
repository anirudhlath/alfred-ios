import Foundation

final class SendVoiceMessageUseCase: Sendable {
    private let chatRepo: any ChatRepositoryProtocol
    private let messageStore: any MessageStoreProtocol

    init(chatRepo: any ChatRepositoryProtocol, messageStore: any MessageStoreProtocol) {
        self.chatRepo = chatRepo
        self.messageStore = messageStore
    }

    func execute(audioData: Data, format: AudioFormat, conversationId: UUID) async throws -> Message {
        let message = try await chatRepo.send(audioData: audioData, format: format)
        try await messageStore.save(message, conversationId: conversationId)
        return message
    }
}
