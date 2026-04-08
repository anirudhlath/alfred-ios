// Packages/AlfredKit/Sources/AlfredKit/DTOs/ServerDTOs.swift
import Foundation

/// Session assignment from server.
public struct SessionDTO: Codable, Sendable {
    public let type: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
    }
}

/// Text + optional audio response from server.
public struct ServerResponseDTO: Codable, Sendable {
    public let type: String
    public let text: String
    public let sessionId: String
    public let audio: String?

    enum CodingKeys: String, CodingKey {
        case type, text, audio
        case sessionId = "session_id"
    }
}

/// Voice transcription intermediate result.
public struct TranscriptionDTO: Codable, Sendable {
    public let type: String
    public let text: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, text
        case sessionId = "session_id"
    }
}

/// Proactive notification (text only, no audio).
public struct NotificationDTO: Codable, Sendable {
    public let type: String
    public let title: String
    public let body: String
    public let urgency: String
    public let notificationId: String?

    enum CodingKeys: String, CodingKey {
        case type, title, body, urgency
        case notificationId = "notification_id"
    }
}

/// Voice-only notification with audio.
public struct VoiceNotificationDTO: Codable, Sendable {
    public let type: String
    public let title: String
    public let audio: String
}

/// Error from server.
public struct ErrorDTO: Codable, Sendable {
    public let type: String
    public let text: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, text
        case sessionId = "session_id"
    }
}
