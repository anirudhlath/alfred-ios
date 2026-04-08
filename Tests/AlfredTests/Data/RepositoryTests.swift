import Foundation
import Testing
import AlfredKit
@testable import Alfred

// MARK: - Mocks

final class MockWebSocketClient: WebSocketClientProtocol, @unchecked Sendable {
    var connectURL: URL?
    var connectSessionId: String?
    var sentMessages: [ClientMessage] = []
    var disconnectCalled = false

    private let messagesContinuation: AsyncStream<ServerMessage>.Continuation
    let messages: AsyncStream<ServerMessage>

    private let stateContinuation: AsyncStream<ConnectionState>.Continuation
    let connectionState: AsyncStream<ConnectionState>

    init() {
        var msgCont: AsyncStream<ServerMessage>.Continuation!
        self.messages = AsyncStream { msgCont = $0 }
        self.messagesContinuation = msgCont

        var stateCont: AsyncStream<ConnectionState>.Continuation!
        self.connectionState = AsyncStream { stateCont = $0 }
        self.stateContinuation = stateCont
    }

    func connect(to url: URL, sessionId: String?) async throws {
        connectURL = url
        connectSessionId = sessionId
    }

    func disconnect() { disconnectCalled = true }

    func send(_ message: ClientMessage) async throws {
        sentMessages.append(message)
    }

    func yieldMessage(_ msg: ServerMessage) {
        messagesContinuation.yield(msg)
    }
}

final class MockRESTClient: RESTClientProtocol, @unchecked Sendable {
    var registeredToken: String?
    var savedIntegration: String?
    var savedFields: [String: String]?

    func healthCheck() async -> Bool { true }
    func getIntegrations() async throws -> [IntegrationDTO] { [] }
    func saveCredentials(integration: String, fields: [String: String]) async throws {
        savedIntegration = integration
        savedFields = fields
    }
    func deleteCredentials(integration: String) async throws {}
    func getIntegrationStatus(integration: String) async throws -> IntegrationStatusDTO {
        IntegrationStatusDTO(name: integration, healthy: true)
    }
    func submitOnboarding(_ payload: OnboardingDTO) async throws {}
    func registerDevice(token: String, platform: String, identity: String) async throws {
        registeredToken = token
    }
    func unregisterDevice(token: String) async throws {}
}

// MARK: - Tests

@Test func chatRepoSendTextCreatesClientMessage() async throws {
    let wsClient = MockWebSocketClient()
    let sessionRepo = SessionRepositoryImpl()
    let chatRepo = ChatRepositoryImpl(webSocketClient: wsClient, sessionRepository: sessionRepo)

    let message = try await chatRepo.send(text: "Hello")
    #expect(message.role == .user)
    #expect(message.content == "Hello")
    #expect(wsClient.sentMessages.count == 1)
}

@Test func chatRepoSendAudioCreatesClientMessage() async throws {
    let wsClient = MockWebSocketClient()
    let sessionRepo = SessionRepositoryImpl()
    let chatRepo = ChatRepositoryImpl(webSocketClient: wsClient, sessionRepository: sessionRepo)

    let audioData = Data([0x01, 0x02, 0x03])
    let message = try await chatRepo.send(audioData: audioData, format: .aac)
    #expect(message.role == .user)
    #expect(wsClient.sentMessages.count == 1)
}

@Test func chatRepoDisconnectDelegatesToWebSocket() async throws {
    let wsClient = MockWebSocketClient()
    let sessionRepo = SessionRepositoryImpl()
    let chatRepo = ChatRepositoryImpl(webSocketClient: wsClient, sessionRepository: sessionRepo)

    chatRepo.disconnect()
    #expect(wsClient.disconnectCalled == true)
}

@Test func integrationRepoSaveCredentialsDelegatesToREST() async throws {
    let restClient = MockRESTClient()
    let repo = IntegrationRepositoryImpl(restClient: restClient)

    try await repo.saveCredentials(integration: "weather", fields: ["key": "val"])
    #expect(restClient.savedIntegration == "weather")
    #expect(restClient.savedFields?["key"] == "val")
}

@Test func integrationRepoCheckStatusReturnsHealthy() async throws {
    let restClient = MockRESTClient()
    let repo = IntegrationRepositoryImpl(restClient: restClient)

    let healthy = try await repo.checkStatus(integration: "weather")
    #expect(healthy == true)
}

@Test func integrationRepoGetAllMapsFromDTO() async throws {
    let restClient = MockRESTClient()
    let repo = IntegrationRepositoryImpl(restClient: restClient)

    let integrations = try await repo.getAll()
    #expect(integrations.isEmpty)
}

@Test func notificationRepoRegistersDeviceToken() async throws {
    let wsClient = MockWebSocketClient()
    let restClient = MockRESTClient()
    let repo = NotificationRepositoryImpl(webSocketClient: wsClient, restClient: restClient)

    let token = Data([0xAB, 0xCD, 0xEF])
    try await repo.registerDevice(token: token)
    #expect(restClient.registeredToken == "abcdef")
}

@Test func sessionRepoSavesAndRestoresConfig() {
    let repo = SessionRepositoryImpl()
    let config = ServerConfig(host: "10.0.0.1", port: 9090)
    repo.saveServerConfig(config)

    let restored = repo.restoreServerConfig()
    #expect(restored?.host == "10.0.0.1")
    #expect(restored?.port == 9090)

    // Cleanup
    repo.clearSession()
}

@Test func sessionRepoSavesAndRestoresSessionId() {
    let repo = SessionRepositoryImpl()
    repo.saveSessionId("test-session-123")

    let restored = repo.restoreSessionId()
    #expect(restored == "test-session-123")

    // Cleanup
    repo.clearSession()
}

@Test func sessionRepoClearSessionRemovesSessionId() {
    let repo = SessionRepositoryImpl()
    repo.saveSessionId("to-be-cleared")
    repo.clearSession()

    let restored = repo.restoreSessionId()
    #expect(restored == nil)
}

@Test func onboardingRepoIsCompleteDefaultsFalse() {
    // Reset any previously stored value
    UserDefaults.standard.removeObject(forKey: "onboarding_complete")
    let restClient = MockRESTClient()
    let repo = OnboardingRepositoryImpl(restClient: restClient)

    #expect(repo.isComplete == false)
}
