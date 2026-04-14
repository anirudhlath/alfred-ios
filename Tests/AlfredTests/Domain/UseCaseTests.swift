import Foundation
import Testing
import AlfredKit
@testable import Alfred

// MARK: - Mock Implementations

final class MockChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    var connectCalled = false
    var disconnectCalled = false
    var sentText: String?
    var sentAudioData: Data?
    var messages: AsyncStream<Message> { AsyncStream { _ in } }
    var connectionState: AsyncStream<AppConnectionState> { AsyncStream { _ in } }

    func connect() async throws { connectCalled = true }
    func disconnect() { disconnectCalled = true }
    func send(text: String) async throws -> Message {
        sentText = text
        return Message(id: UUID(), role: .user, content: text, timestamp: Date(), audio: nil)
    }
    func send(audioData: Data, format: AudioFormat) async throws -> Message {
        sentAudioData = audioData
        return Message(id: UUID(), role: .user, content: "transcribed", timestamp: Date(), audio: nil)
    }
}

final class MockMessageStore: MessageStoreProtocol, @unchecked Sendable {
    var savedMessages: [Message] = []
    var createdConversationIds: [UUID] = []
    var storedMessages: [UUID: [Message]] = [:]

    func save(_ message: Message, conversationId: UUID) async throws {
        savedMessages.append(message)
    }
    func fetchMessages(conversationId: UUID) async throws -> [Message] {
        storedMessages[conversationId] ?? []
    }
    func fetchConversations() async throws -> [Conversation] { [] }
    func createConversation(id: UUID) async throws {
        createdConversationIds.append(id)
    }
    func deleteConversation(_ id: UUID) async throws {}
}

final class MockSessionRepository: SessionRepositoryProtocol, @unchecked Sendable {
    var savedSessionId: String?
    var savedConversationId: UUID?
    func saveSessionId(_ id: String) { savedSessionId = id }
    func restoreSessionId() -> String? { savedSessionId }
    func clearSession() { savedSessionId = nil; savedConversationId = nil }
    func saveServerConfig(_ config: ServerConfig) {}
    func restoreServerConfig() -> ServerConfig? { nil }
    func saveConversationId(_ id: UUID) { savedConversationId = id }
    func restoreConversationId() -> UUID? { savedConversationId }
}

final class MockNotificationRepository: NotificationRepositoryProtocol, @unchecked Sendable {
    var registeredToken: Data?
    var unregisterDeviceCalled = false
    var notifications: AsyncStream<AppNotification> { AsyncStream { _ in } }
    var rawMessages: AsyncStream<ServerMessage> { AsyncStream { _ in } }

    func registerDevice(token: Data) async throws {
        registeredToken = token
    }
    func unregisterDevice() async throws {
        unregisterDeviceCalled = true
    }
}

final class MockOnboardingRepository: OnboardingRepositoryProtocol, @unchecked Sendable {
    var submittedPreferences: UserPreferences?
    var isComplete: Bool = false

    func submit(preferences: UserPreferences) async throws {
        submittedPreferences = preferences
    }
}

final class MockIntegrationRepository: IntegrationRepositoryProtocol, @unchecked Sendable {
    var savedCredentials: (integration: String, fields: [String: String])?
    var deletedIntegration: String?
    var checkedIntegration: String?

    func getAll() async throws -> [Integration] { [] }
    func saveCredentials(integration: String, fields: [String: String]) async throws {
        savedCredentials = (integration, fields)
    }
    func deleteCredentials(integration: String) async throws {
        deletedIntegration = integration
    }
    func checkStatus(integration: String) async throws -> Bool {
        checkedIntegration = integration
        return true
    }
}

// MARK: - SendTextMessageUseCase Tests

@Test func sendTextMessageCallsRepoAndStore() async throws {
    let chatRepo = MockChatRepository()
    let store = MockMessageStore()
    let useCase = SendTextMessageUseCase(chatRepo: chatRepo, messageStore: store)

    let msg = try await useCase.execute(text: "Hello", conversationId: UUID())
    #expect(chatRepo.sentText == "Hello")
    #expect(store.savedMessages.count == 1)
    #expect(msg.content == "Hello")
}

@Test func sendTextMessageReturnsCorrectMessage() async throws {
    let chatRepo = MockChatRepository()
    let store = MockMessageStore()
    let useCase = SendTextMessageUseCase(chatRepo: chatRepo, messageStore: store)

    let conversationId = UUID()
    let msg = try await useCase.execute(text: "Test message", conversationId: conversationId)
    #expect(msg.role == .user)
    #expect(msg.content == "Test message")
    #expect(store.savedMessages.first?.id == msg.id)
}

// MARK: - SendVoiceMessageUseCase Tests

@Test func sendVoiceMessageCallsRepoAndStore() async throws {
    let chatRepo = MockChatRepository()
    let store = MockMessageStore()
    let useCase = SendVoiceMessageUseCase(chatRepo: chatRepo, messageStore: store)

    let audioData = Data([0x01, 0x02, 0x03])
    let msg = try await useCase.execute(audioData: audioData, format: .wav, conversationId: UUID())
    #expect(chatRepo.sentAudioData == audioData)
    #expect(store.savedMessages.count == 1)
    #expect(msg.content == "transcribed")
}

// MARK: - ConnectUseCase Tests

@Test func connectUseCaseCallsRepo() async throws {
    let chatRepo = MockChatRepository()
    let sessionRepo = MockSessionRepository()
    let useCase = ConnectUseCase(chatRepo: chatRepo, sessionRepo: sessionRepo)

    try await useCase.execute()
    #expect(chatRepo.connectCalled == true)
}

// MARK: - ObserveMessagesUseCase Tests

@Test func observeMessagesUseCaseReturnsStream() {
    let chatRepo = MockChatRepository()
    let useCase = ObserveMessagesUseCase(chatRepo: chatRepo)

    let stream = useCase.execute()
    let _: AsyncStream<Message> = stream
}

// MARK: - ObserveNotificationsUseCase Tests

@Test func observeNotificationsUseCaseReturnsStream() {
    let notificationRepo = MockNotificationRepository()
    let useCase = ObserveNotificationsUseCase(notificationRepo: notificationRepo)

    let stream = useCase.execute()
    let _: AsyncStream<AppNotification> = stream
}

// MARK: - RegisterForPushUseCase Tests

@Test func registerForPushUseCaseRegistersToken() async throws {
    let notificationRepo = MockNotificationRepository()
    let useCase = RegisterForPushUseCase(notificationRepo: notificationRepo)

    let token = Data([0xAB, 0xCD, 0xEF])
    try await useCase.execute(deviceToken: token)
    #expect(notificationRepo.registeredToken == token)
}

// MARK: - SubmitOnboardingUseCase Tests

@Test func submitOnboardingUseCaseSubmitsPreferences() async throws {
    let onboardingRepo = MockOnboardingRepository()
    let useCase = SubmitOnboardingUseCase(onboardingRepo: onboardingRepo)

    let prefs = UserPreferences(
        wakeTime: "7:00 AM",
        workAddress: nil,
        dietaryRestrictions: nil,
        proactivityLevel: .moderate,
        guestControls: []
    )
    try await useCase.execute(preferences: prefs)
    #expect(onboardingRepo.submittedPreferences?.wakeTime == "7:00 AM")
    #expect(onboardingRepo.submittedPreferences?.proactivityLevel == .moderate)
}

// MARK: - ManageIntegrationsUseCase Tests

@Test func manageIntegrationsGetAllReturnsIntegrations() async throws {
    let integrationRepo = MockIntegrationRepository()
    let useCase = ManageIntegrationsUseCase(integrationRepo: integrationRepo)

    let integrations = try await useCase.getAll()
    #expect(integrations.isEmpty)
}

@Test func manageIntegrationsSaveCredentials() async throws {
    let integrationRepo = MockIntegrationRepository()
    let useCase = ManageIntegrationsUseCase(integrationRepo: integrationRepo)

    let fields = ["api_key": "secret123", "username": "user@example.com"]
    try await useCase.saveCredentials(integration: "calendar", fields: fields)
    #expect(integrationRepo.savedCredentials?.integration == "calendar")
    #expect(integrationRepo.savedCredentials?.fields["api_key"] == "secret123")
}

@Test func manageIntegrationsDeleteCredentials() async throws {
    let integrationRepo = MockIntegrationRepository()
    let useCase = ManageIntegrationsUseCase(integrationRepo: integrationRepo)

    try await useCase.deleteCredentials(integration: "weather")
    #expect(integrationRepo.deletedIntegration == "weather")
}

@Test func manageIntegrationsCheckStatus() async throws {
    let integrationRepo = MockIntegrationRepository()
    let useCase = ManageIntegrationsUseCase(integrationRepo: integrationRepo)

    let isConnected = try await useCase.checkStatus(integration: "calendar")
    #expect(isConnected == true)
    #expect(integrationRepo.checkedIntegration == "calendar")
}
