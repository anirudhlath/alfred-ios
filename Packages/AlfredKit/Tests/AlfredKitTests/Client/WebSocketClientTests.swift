// Packages/AlfredKit/Tests/AlfredKitTests/Client/WebSocketClientTests.swift
import Foundation
import Testing
@testable import AlfredKit

@Test func clientMessageTextEncodesWithSessionId() throws {
    let msg = ClientMessage.text(content: "hello", identity: "sir")
    let data = try msg.encode(sessionId: "sess-123")
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(json["type"] as? String == "text")
    #expect(json["content"] as? String == "hello")
    #expect(json["identity"] as? String == "sir")
    #expect(json["channel"] as? String == "ios")
    #expect(json["session_id"] as? String == "sess-123")
}

@Test func clientMessageAudioEncodesAsDataURL() throws {
    let audioData = Data([0x01, 0x02, 0x03])
    let msg = ClientMessage.audio(data: audioData, mimeType: "audio/aac", identity: "sir")
    let data = try msg.encode(sessionId: nil)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(json["type"] as? String == "audio")
    let content = json["content"] as? String ?? ""
    #expect(content.hasPrefix("data:audio/aac;base64,"))
}

@Test func webSocketClientProtocolConformance() {
    // Verify the protocol exists and WebSocketClient conforms
    let _: any WebSocketClientProtocol.Type = WebSocketClient.self
}
