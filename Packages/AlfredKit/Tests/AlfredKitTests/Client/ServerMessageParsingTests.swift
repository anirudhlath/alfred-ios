// Packages/AlfredKit/Tests/AlfredKitTests/Client/ServerMessageParsingTests.swift
import Foundation
import Testing
@testable import AlfredKit

@Test func parsesSessionMessage() throws {
    let json = #"{"type": "session", "session_id": "abc-123"}"#.data(using: .utf8)!
    let msg = try ServerMessage.parse(from: json)
    guard case .session(let sessionId) = msg else {
        Issue.record("Expected .session")
        return
    }
    #expect(sessionId == "abc-123")
}

@Test func parsesResponseMessage() throws {
    let json = #"{"type": "response", "text": "Hello", "session_id": "abc", "audio": null}"#.data(using: .utf8)!
    let msg = try ServerMessage.parse(from: json)
    guard case .response(let text, let sessionId, let audio) = msg else {
        Issue.record("Expected .response")
        return
    }
    #expect(text == "Hello")
    #expect(sessionId == "abc")
    #expect(audio == nil)
}

@Test func parsesResponseWithAudio() throws {
    let json = #"{"type": "response", "text": "Hi", "session_id": "abc", "audio": "AQID"}"#.data(using: .utf8)!
    let msg = try ServerMessage.parse(from: json)
    guard case .response(_, _, let audio) = msg else {
        Issue.record("Expected .response")
        return
    }
    #expect(audio != nil)
}

@Test func parsesNotificationMessage() throws {
    let json = #"{"type": "notification", "title": "Alert", "body": "Rain", "urgency": "important"}"#.data(using: .utf8)!
    let msg = try ServerMessage.parse(from: json)
    guard case .notification(let title, let body, let urgency) = msg else {
        Issue.record("Expected .notification")
        return
    }
    #expect(title == "Alert")
    #expect(body == "Rain")
    #expect(urgency == "important")
}

@Test func parsesVoiceNotification() throws {
    let json = #"{"type": "voice_notification", "title": "Trigger", "audio": "AQIDBA=="}"#.data(using: .utf8)!
    let msg = try ServerMessage.parse(from: json)
    guard case .voiceNotification(let title, let audio) = msg else {
        Issue.record("Expected .voiceNotification")
        return
    }
    #expect(title == "Trigger")
    #expect(audio != nil)
}

@Test func parsesTranscription() throws {
    let json = #"{"type": "transcription", "text": "hello", "session_id": "abc"}"#.data(using: .utf8)!
    let msg = try ServerMessage.parse(from: json)
    guard case .transcription(let text, _) = msg else {
        Issue.record("Expected .transcription")
        return
    }
    #expect(text == "hello")
}

@Test func parsesError() throws {
    let json = #"{"type": "error", "text": "fail", "session_id": "abc"}"#.data(using: .utf8)!
    let msg = try ServerMessage.parse(from: json)
    guard case .error(let text, _) = msg else {
        Issue.record("Expected .error")
        return
    }
    #expect(text == "fail")
}

@Test func unknownTypeThrows() {
    let json = #"{"type": "unknown_thing"}"#.data(using: .utf8)!
    #expect(throws: ServerMessageError.self) {
        try ServerMessage.parse(from: json)
    }
}
