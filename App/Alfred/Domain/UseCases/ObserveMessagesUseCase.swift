import Foundation

final class ObserveMessagesUseCase: Sendable {
    private let chatRepo: any ChatRepositoryProtocol

    init(chatRepo: any ChatRepositoryProtocol) {
        self.chatRepo = chatRepo
    }

    func execute() -> AsyncStream<Message> {
        chatRepo.messages
    }
}
