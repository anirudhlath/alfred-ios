import Foundation
import SwiftUI
import AlfredKit

@Observable
final class AppContainer {
    private(set) var webSocketClient: WebSocketClient
    private(set) var restClient: RESTClient
    let sessionRepository: SessionRepositoryImpl
    private(set) var chatRepository: ChatRepositoryImpl
    private(set) var notificationRepository: NotificationRepositoryImpl
    private(set) var integrationRepository: IntegrationRepositoryImpl
    private(set) var onboardingRepository: OnboardingRepositoryImpl
    let messageStore: MessageStoreImpl

    // Use cases
    private(set) var connectUseCase: ConnectUseCase
    private(set) var sendTextMessageUseCase: SendTextMessageUseCase
    private(set) var sendVoiceMessageUseCase: SendVoiceMessageUseCase
    private(set) var observeMessagesUseCase: ObserveMessagesUseCase
    private(set) var observeNotificationsUseCase: ObserveNotificationsUseCase
    private(set) var registerForPushUseCase: RegisterForPushUseCase
    private(set) var submitOnboardingUseCase: SubmitOnboardingUseCase
    private(set) var manageIntegrationsUseCase: ManageIntegrationsUseCase

    init() {
        let sessionRepo = SessionRepositoryImpl()
        let config = sessionRepo.restoreServerConfig() ?? ServerConfig.default
        let serverConfig = ServerConfiguration(host: config.host, port: config.port)

        let wsClient = WebSocketClient()
        let rest = RESTClient(configuration: serverConfig)
        let msgStore = MessageStoreImpl()

        self.sessionRepository = sessionRepo
        self.webSocketClient = wsClient
        self.restClient = rest
        self.messageStore = msgStore

        // Repositories
        let chatRepo = ChatRepositoryImpl(webSocketClient: wsClient, sessionRepository: sessionRepo)
        let notifRepo = NotificationRepositoryImpl(webSocketClient: wsClient, restClient: rest)
        let integRepo = IntegrationRepositoryImpl(restClient: rest)
        let onboardRepo = OnboardingRepositoryImpl(restClient: rest)

        self.chatRepository = chatRepo
        self.notificationRepository = notifRepo
        self.integrationRepository = integRepo
        self.onboardingRepository = onboardRepo

        // Use cases
        self.connectUseCase = ConnectUseCase(chatRepo: chatRepo, sessionRepo: sessionRepo)
        self.sendTextMessageUseCase = SendTextMessageUseCase(chatRepo: chatRepo, messageStore: msgStore)
        self.sendVoiceMessageUseCase = SendVoiceMessageUseCase(chatRepo: chatRepo, messageStore: msgStore)
        self.observeMessagesUseCase = ObserveMessagesUseCase(chatRepo: chatRepo)
        self.observeNotificationsUseCase = ObserveNotificationsUseCase(notificationRepo: notifRepo)
        self.registerForPushUseCase = RegisterForPushUseCase(notificationRepo: notifRepo)
        self.submitOnboardingUseCase = SubmitOnboardingUseCase(onboardingRepo: onboardRepo)
        self.manageIntegrationsUseCase = ManageIntegrationsUseCase(integrationRepo: integRepo)
    }

    /// Reconfigure all clients when server config changes in settings.
    func reconfigure(with config: ServerConfig) {
        webSocketClient.disconnect()
        sessionRepository.saveServerConfig(config)

        let serverConfig = ServerConfiguration(host: config.host, port: config.port)
        let wsClient = WebSocketClient()
        let rest = RESTClient(configuration: serverConfig)

        self.webSocketClient = wsClient
        self.restClient = rest

        // Rewire repositories
        let chatRepo = ChatRepositoryImpl(webSocketClient: wsClient, sessionRepository: sessionRepository)
        let notifRepo = NotificationRepositoryImpl(webSocketClient: wsClient, restClient: rest)
        let integRepo = IntegrationRepositoryImpl(restClient: rest)
        let onboardRepo = OnboardingRepositoryImpl(restClient: rest)

        self.chatRepository = chatRepo
        self.notificationRepository = notifRepo
        self.integrationRepository = integRepo
        self.onboardingRepository = onboardRepo

        // Rewire use cases
        self.connectUseCase = ConnectUseCase(chatRepo: chatRepo, sessionRepo: sessionRepository)
        self.sendTextMessageUseCase = SendTextMessageUseCase(chatRepo: chatRepo, messageStore: messageStore)
        self.sendVoiceMessageUseCase = SendVoiceMessageUseCase(chatRepo: chatRepo, messageStore: messageStore)
        self.observeMessagesUseCase = ObserveMessagesUseCase(chatRepo: chatRepo)
        self.observeNotificationsUseCase = ObserveNotificationsUseCase(notificationRepo: notifRepo)
        self.registerForPushUseCase = RegisterForPushUseCase(notificationRepo: notifRepo)
        self.submitOnboardingUseCase = SubmitOnboardingUseCase(onboardingRepo: onboardRepo)
        self.manageIntegrationsUseCase = ManageIntegrationsUseCase(integrationRepo: integRepo)
    }
}
