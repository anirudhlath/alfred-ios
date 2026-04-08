import Foundation

final class ConnectUseCase: Sendable {
    private let chatRepo: any ChatRepositoryProtocol
    private let sessionRepo: any SessionRepositoryProtocol

    init(chatRepo: any ChatRepositoryProtocol, sessionRepo: any SessionRepositoryProtocol) {
        self.chatRepo = chatRepo
        self.sessionRepo = sessionRepo
    }

    func execute() async throws {
        try await chatRepo.connect()
    }
}
