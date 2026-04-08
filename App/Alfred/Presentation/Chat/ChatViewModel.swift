import Foundation
import SwiftUI

@Observable
@MainActor
final class ChatViewModel {
    var messages: [Message] = []
    var connectionState: AppConnectionState = .disconnected
    var isRecording = false
    var isWaiting = false
    var inputText = ""

    private var conversationId = UUID()
    private var container: AppContainer?

    func configure(with container: AppContainer) {
        guard self.container == nil else { return }
        self.container = container

        Task {
            try? await container.connectUseCase.execute()
        }

        Task {
            for await message in container.observeMessagesUseCase.execute() {
                self.messages.append(message)
                if message.role == .alfred {
                    self.isWaiting = false
                }
            }
        }

        Task {
            for await state in container.chatRepository.connectionState {
                self.connectionState = state
            }
        }
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let container else { return }
        inputText = ""
        isWaiting = true

        Task {
            do {
                let userMessage = try await container.sendTextMessageUseCase.execute(
                    text: text,
                    conversationId: conversationId
                )
                messages.append(userMessage)
            } catch {
                isWaiting = false
            }
        }
    }

    func reconnect() {
        guard let container else { return }
        Task {
            try? await container.connectUseCase.execute()
        }
    }
}
