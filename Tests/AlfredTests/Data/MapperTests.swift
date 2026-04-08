import Foundation
import Testing
import AlfredKit
@testable import Alfred

@Test func messageMapperMapsResponse() {
    let serverMsg = ServerMessage.response(text: "Hello", sessionId: "abc", audio: nil)
    let message = MessageMapper.toDomain(from: serverMsg)
    #expect(message?.role == .alfred)
    #expect(message?.content == "Hello")
    #expect(message?.audio == nil)
}

@Test func messageMapperMapsResponseWithAudio() {
    let audioData = Data([0x01, 0x02])
    let serverMsg = ServerMessage.response(text: "Hi", sessionId: "abc", audio: audioData)
    let message = MessageMapper.toDomain(from: serverMsg)
    #expect(message?.audio != nil)
}

@Test func messageMapperReturnsNilForNotification() {
    let serverMsg = ServerMessage.notification(title: "Alert", body: "Rain", urgency: "important")
    let message = MessageMapper.toDomain(from: serverMsg)
    #expect(message == nil)
}

@Test func notificationMapperMapsNotification() {
    let serverMsg = ServerMessage.notification(title: "Alert", body: "Rain at 3pm", urgency: "important")
    let notif = NotificationMapper.toDomain(from: serverMsg)
    #expect(notif?.title == "Alert")
    #expect(notif?.body == "Rain at 3pm")
    #expect(notif?.urgency == .important)
    #expect(notif?.audio == nil)
}

@Test func notificationMapperMapsVoiceNotification() {
    let audioData = Data([0x01, 0x02])
    let serverMsg = ServerMessage.voiceNotification(title: "Trigger", audio: audioData)
    let notif = NotificationMapper.toDomain(from: serverMsg)
    #expect(notif?.title == "Trigger")
    #expect(notif?.body == nil)
    #expect(notif?.audio != nil)
}

@Test func notificationMapperMapsUrgencyLevels() {
    let urgent = ServerMessage.notification(title: "T", body: "B", urgency: "urgent")
    #expect(NotificationMapper.toDomain(from: urgent)?.urgency == .urgent)

    let info = ServerMessage.notification(title: "T", body: "B", urgency: "informational")
    #expect(NotificationMapper.toDomain(from: info)?.urgency == .informational)

    let unknown = ServerMessage.notification(title: "T", body: "B", urgency: "something")
    #expect(NotificationMapper.toDomain(from: unknown)?.urgency == .informational)
}

@Test func integrationMapperMapsDTO() {
    let fieldDTO = CredentialFieldDTO(label: "API Key", type: "password", required: true, transient: nil)
    let schemaDTO = IntegrationSchemaDTO(fields: ["api_key": fieldDTO])
    let dto = IntegrationDTO(name: "weather", category: "env", description: "Weather data", schema: schemaDTO, configured: ["api_key": true])

    let integration = IntegrationMapper.toDomain(from: dto)
    #expect(integration.name == "weather")
    #expect(integration.description == "Weather data")
    #expect(integration.configured == true)
    #expect(integration.schema.count == 1)
    #expect(integration.schema[0].type == .password)
}

@Test func integrationMapperHandlesUnconfigured() {
    let schemaDTO = IntegrationSchemaDTO(fields: [:])
    let dto = IntegrationDTO(name: "cal", category: nil, description: nil, schema: schemaDTO, configured: [:])
    let integration = IntegrationMapper.toDomain(from: dto)
    #expect(integration.configured == false)
    #expect(integration.description == "")
}

@Test func onboardingMapperConvertsPreferences() {
    let prefs = UserPreferences(
        wakeTime: "7:00 AM",
        workAddress: "123 Main St",
        dietaryRestrictions: "Vegan",
        proactivityLevel: .opinionated,
        guestControls: ["Lighting control"]
    )
    let dto = OnboardingMapper.toDTO(from: prefs)
    #expect(dto.wakeTime == "7:00 AM")
    #expect(dto.workAddress == "123 Main St")
    #expect(dto.proactivityLevel == "opinionated")
    #expect(dto.guestControls == ["Lighting control"])
}

@Test func onboardingMapperHandlesDefaults() {
    let prefs = UserPreferences.default
    let dto = OnboardingMapper.toDTO(from: prefs)
    #expect(dto.wakeTime == nil)
    #expect(dto.guestControls == nil)
}
