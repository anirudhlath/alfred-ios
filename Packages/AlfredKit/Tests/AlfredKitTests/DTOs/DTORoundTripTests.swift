// Packages/AlfredKit/Tests/AlfredKitTests/DTOs/DTORoundTripTests.swift
import Foundation
import Testing
@testable import AlfredKit

@Test func textMessageDTOEncodesCorrectly() throws {
    let dto = TextMessageDTO(type: "text", content: "Hello", identity: "sir", channel: "ios", sessionId: nil)
    let data = try JSONEncoder().encode(dto)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    #expect(json["type"] as? String == "text")
    #expect(json["content"] as? String == "Hello")
    #expect(json["identity"] as? String == "sir")
    #expect(json["channel"] as? String == "ios")
    #expect(json["session_id"] == nil || json["session_id"] is NSNull)
}

@Test func audioMessageDTOEncodesCorrectly() throws {
    let dto = AudioMessageDTO(
        type: "audio",
        content: "data:audio/aac;base64,AAAA",
        identity: "sir",
        channel: "ios"
    )
    let data = try JSONEncoder().encode(dto)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    #expect(json["type"] as? String == "audio")
    #expect(json["channel"] as? String == "ios")
}

@Test func serverResponseDTODecodesCorrectly() throws {
    let json = """
    {"type": "response", "text": "It's sunny.", "session_id": "abc-123", "audio": null}
    """.data(using: .utf8)!

    let dto = try JSONDecoder().decode(ServerResponseDTO.self, from: json)
    #expect(dto.type == "response")
    #expect(dto.text == "It's sunny.")
    #expect(dto.sessionId == "abc-123")
    #expect(dto.audio == nil)
}

@Test func sessionDTODecodesCorrectly() throws {
    let json = """
    {"type": "session", "session_id": "550e8400-e29b-41d4-a716-446655440000"}
    """.data(using: .utf8)!

    let dto = try JSONDecoder().decode(SessionDTO.self, from: json)
    #expect(dto.sessionId == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func notificationDTODecodesCorrectly() throws {
    let json = """
    {"type": "notification", "title": "Alert", "body": "Rain at 3pm", "urgency": "important", "notification_id": "abc-123"}
    """.data(using: .utf8)!

    let dto = try JSONDecoder().decode(NotificationDTO.self, from: json)
    #expect(dto.title == "Alert")
    #expect(dto.urgency == "important")
    #expect(dto.notificationId == "abc-123")
}

@Test func notificationDTODecodesWithoutId() throws {
    let json = """
    {"type": "notification", "title": "Alert", "body": "Rain", "urgency": "informational"}
    """.data(using: .utf8)!

    let dto = try JSONDecoder().decode(NotificationDTO.self, from: json)
    #expect(dto.notificationId == nil)
}

@Test func voiceNotificationDTODecodesCorrectly() throws {
    let json = """
    {"type": "voice_notification", "title": "Trigger", "audio": "base64data"}
    """.data(using: .utf8)!

    let dto = try JSONDecoder().decode(VoiceNotificationDTO.self, from: json)
    #expect(dto.title == "Trigger")
    #expect(dto.audio == "base64data")
}

@Test func errorDTODecodesCorrectly() throws {
    let json = """
    {"type": "error", "text": "Something failed", "session_id": "abc"}
    """.data(using: .utf8)!

    let dto = try JSONDecoder().decode(ErrorDTO.self, from: json)
    #expect(dto.text == "Something failed")
}

@Test func integrationDTODecodesCorrectly() throws {
    let json = """
    {
        "name": "weather",
        "category": "environment",
        "schema": {
            "fields": {
                "api_key": {"label": "API Key", "type": "password", "required": true, "transient": false}
            }
        },
        "configured": {"api_key": true}
    }
    """.data(using: .utf8)!

    let dto = try JSONDecoder().decode(IntegrationDTO.self, from: json)
    #expect(dto.name == "weather")
}

@Test func deviceRegistrationDTOEncodesCorrectly() throws {
    let dto = DeviceRegistrationDTO(deviceToken: "abc123", platform: "ios", identity: "sir")
    let data = try JSONEncoder().encode(dto)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    #expect(json["device_token"] as? String == "abc123")
    #expect(json["platform"] as? String == "ios")
}
