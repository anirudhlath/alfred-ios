import Foundation
import Testing
@testable import Alfred

@Test func messageCreation() {
    let msg = Message(id: UUID(), role: .user, content: "Hello", timestamp: Date(), audio: nil)
    #expect(msg.role == .user)
    #expect(msg.content == "Hello")
    #expect(msg.audio == nil)
}

@Test func notificationCreation() {
    let notif = AppNotification(id: UUID(), title: "Alert", body: "Rain", urgency: .important, timestamp: Date(), audio: nil)
    #expect(notif.urgency == .important)
    #expect(notif.body == "Rain")
}

@Test func integrationCreation() {
    let field = CredentialField(key: "api_key", label: "API Key", type: .password, required: true)
    let integration = Integration(name: "weather", description: "Weather data", configured: true, schema: [field])
    #expect(integration.name == "weather")
    #expect(integration.schema.count == 1)
    #expect(integration.schema[0].type == .password)
}

@Test func userPreferencesDefaults() {
    let prefs = UserPreferences.default
    #expect(prefs.proactivityLevel == .moderate)
    #expect(prefs.guestControls.isEmpty)
}

@Test func serverConfigURLs() {
    let config = ServerConfig(host: "192.0.2.1", port: 8081)
    #expect(config.host == "192.0.2.1")
    #expect(config.port == 8081)
}
