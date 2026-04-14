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
    let audioService: AudioService

    /// Notifications captured eagerly — regardless of which tab is active.
    var pendingNotifications: [AppNotification] = []
    private var notificationObservationStarted = false

    // Use cases
    private(set) var connectUseCase: ConnectUseCase
    private(set) var sendTextMessageUseCase: SendTextMessageUseCase
    private(set) var sendVoiceMessageUseCase: SendVoiceMessageUseCase
    private(set) var observeMessagesUseCase: ObserveMessagesUseCase
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
        let audio = AudioService()

        self.sessionRepository = sessionRepo
        self.webSocketClient = wsClient
        self.restClient = rest
        self.messageStore = msgStore
        self.audioService = audio

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
        self.registerForPushUseCase = RegisterForPushUseCase(notificationRepo: notifRepo)
        self.submitOnboardingUseCase = SubmitOnboardingUseCase(onboardingRepo: onboardRepo)
        self.manageIntegrationsUseCase = ManageIntegrationsUseCase(integrationRepo: integRepo)
    }

    /// Start observing notifications eagerly so none are missed before the tab is visited.
    /// Text notifications go to the list; voice notifications auto-play immediately.
    @MainActor
    func startNotificationObservation() {
        guard !notificationObservationStarted else { return }
        notificationObservationStarted = true

        Task {
            for await serverMsg in notificationRepository.rawMessages {
                switch serverMsg {
                case .notification:
                    if let notif = NotificationMapper.toDomain(from: serverMsg) {
                        pendingNotifications.insert(notif, at: 0)
                    }
                case .voiceNotification(_, let audio):
                    await audioService.player.play(audio)
                default:
                    break
                }
            }
        }
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
        self.registerForPushUseCase = RegisterForPushUseCase(notificationRepo: notifRepo)
        self.submitOnboardingUseCase = SubmitOnboardingUseCase(onboardingRepo: onboardRepo)
        self.manageIntegrationsUseCase = ManageIntegrationsUseCase(integrationRepo: integRepo)

        // Restart notification observation with the new repository
        notificationObservationStarted = false
    }
}
