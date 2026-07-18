import Foundation
import os
import SwiftUI
import AlfredKit

private let log = Logger(subsystem: "com.anirudhlath.alfred", category: "ChatViewModel")

@Observable
@MainActor
final class ChatViewModel {
    var messages: [Message] = []
    var connectionState: AppConnectionState = .disconnected
    var isRecording = false
    var isWaiting = false
    var inputText = ""
    var errorMessage: String?

    private var conversationId = UUID()
    private var container: AppContainer?
    private var recordingStream: AsyncStream<Data>?
    private var recordedChunks: [Data] = []
    private var micPermissionGranted = false

    func configure(with container: AppContainer) {
        guard self.container == nil else { return }
        self.container = container

        if let savedId = container.sessionRepository.restoreConversationId() {
            conversationId = savedId
        } else {
            persistNewConversation(container: container)
        }

        Task {
            do {
                let restored = try await container.messageStore.fetchMessages(
                    conversationId: conversationId
                )
                self.messages = restored
            } catch {
                log.error("Failed to restore messages: \(error)")
            }
        }

        Task { try? await container.connectUseCase.execute() }

        Task {
            for await message in container.observeMessagesUseCase.execute() {
                self.messages.append(message)
                try? await container.messageStore.save(message, conversationId: conversationId)
                if message.role == .alfred {
                    self.isWaiting = false
                    if let audio = message.audio {
                        await container.audioService.player.play(audio)
                    }
                }
            }
        }

        Task {
            for await state in container.chatRepository.connectionState {
                self.connectionState = state
            }
        }

        Task {
            for await _ in Self.sessionClearedEvents() {
                resetState()
            }
        }
    }

    /// Bridges `NotificationCenter`'s block-based API into a `Void`-typed `AsyncStream`.
    /// `NotificationCenter.default.notifications(named:)` yields a non-`Sendable`
    /// `Notification`, which Swift 6 strict concurrency rejects when the sequence is
    /// awaited from a `@MainActor` context (its `AsyncIteratorProtocol.next()` requirement
    /// is nonisolated). Re-wrapping as `AsyncStream<Void>` avoids sending the notification
    /// itself across the actor boundary.
    private static func sessionClearedEvents() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let token = NotificationCenter.default.addObserver(
                forName: .alfredSessionCleared, object: nil, queue: .main
            ) { _ in
                continuation.yield(())
            }
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(token)
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
                log.error("Failed to send message: \(error)")
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
        if !micPermissionGranted {
            let granted = await container.audioService.requestMicrophonePermission()
            micPermissionGranted = granted
            guard granted else { return }
        }

        do {
            recordedChunks = []
            let stream = try container.audioService.recorder.start(format: .aac)
            recordingStream = stream
            isRecording = true

            Task {
                for await chunk in stream {
                    recordedChunks.append(chunk)
                }
            }
        } catch {
            log.error("Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        guard let container else { return }
        container.audioService.recorder.stop()
        isRecording = false

        var audioData = Data()
        audioData.reserveCapacity(recordedChunks.reduce(0) { $0 + $1.count })
        recordedChunks.forEach { audioData.append($0) }
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
                log.error("Failed to send voice message: \(error)")
                isWaiting = false
            }
        }
    }

    func resetState() {
        messages = []
        conversationId = UUID()
        isWaiting = false
        isRecording = false
        inputText = ""
        if let container {
            persistNewConversation(container: container)
        }
    }

    private func persistNewConversation(container: AppContainer) {
        container.sessionRepository.saveConversationId(conversationId)
        Task { try? await container.messageStore.createConversation(id: conversationId) }
    }
}
