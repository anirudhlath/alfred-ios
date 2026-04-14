import Foundation
import SwiftUI
import AlfredKit

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
    private var recordingStream: AsyncStream<Data>?
    private var recordedChunks: [Data] = []
    private var micPermissionGranted = false

    func configure(with container: AppContainer) {
        guard self.container == nil else { return }
        self.container = container

        // Restore persisted conversation or start a new one
        if let savedId = container.sessionRepository.restoreConversationId() {
            conversationId = savedId
        } else {
            container.sessionRepository.saveConversationId(conversationId)
            Task {
                try? await container.messageStore.createConversation(id: conversationId)
            }
        }

        // Restore persisted messages
        Task {
            do {
                let restored = try await container.messageStore.fetchMessages(
                    conversationId: conversationId
                )
                self.messages = restored
            } catch {}
        }

        Task {
            try? await container.connectUseCase.execute()
        }

        Task {
            for await message in container.observeMessagesUseCase.execute() {
                self.messages.append(message)
                if message.role == .alfred {
                    self.isWaiting = false
                    // Auto-play audio responses
                    if let audio = message.audio {
                        Task {
                            await container.audioService.player.play(audio)
                        }
                    }
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

    func toggleRecording() {
        guard let container else { return }
        if isRecording {
            stopRecording()
        } else {
            Task {
                await startRecording(container: container)
            }
        }
    }

    func reconnect() {
        guard let container else { return }
        Task {
            try? await container.connectUseCase.execute()
        }
    }

    // MARK: - Private

    private func startRecording(container: AppContainer) async {
        // Request mic permission on first attempt
        if !micPermissionGranted {
            let granted = await container.audioService.requestMicrophonePermission()
            micPermissionGranted = granted
            guard granted else { return }
        }

        do {
            try container.audioService.configureAudioSession()
            recordedChunks = []
            let stream = try container.audioService.recorder.start(format: .aac)
            recordingStream = stream
            isRecording = true

            // Collect audio chunks in background
            Task {
                for await chunk in stream {
                    recordedChunks.append(chunk)
                }
            }
        } catch {}
    }

    private func stopRecording() {
        guard let container else { return }
        container.audioService.recorder.stop()
        isRecording = false

        let audioData = recordedChunks.reduce(Data()) { $0 + $1 }
        recordedChunks = []
        recordingStream = nil

        guard !audioData.isEmpty else { return }
        isWaiting = true

        Task {
            do {
                let userMessage = try await container.sendVoiceMessageUseCase.execute(
                    audioData: audioData,
                    format: .aac,
                    conversationId: conversationId
                )
                messages.append(userMessage)
            } catch {
                isWaiting = false
            }
        }
    }
}
