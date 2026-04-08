import Foundation

public enum ServerMessageError: Error, Sendable {
    case unknownType(String)
    case malformedPayload(String)
}

/// Parsed server messages from the Alfred WebSocket.
public enum ServerMessage: Sendable {
    case session(sessionId: String)
    case response(text: String, sessionId: String, audio: Data?)
    case transcription(text: String, sessionId: String)
    case notification(title: String, body: String, urgency: String)
    case voiceNotification(title: String, audio: Data)
    case error(text: String, sessionId: String)

    /// Parse a raw JSON Data payload from the WebSocket into a typed ServerMessage.
    public static func parse(from data: Data) throws -> ServerMessage {
        let decoder = JSONDecoder()

        struct TypePeek: Decodable { let type: String }
        let peek = try decoder.decode(TypePeek.self, from: data)

        switch peek.type {
        case "session":
            let dto = try decoder.decode(SessionDTO.self, from: data)
            return .session(sessionId: dto.sessionId)

        case "response":
            let dto = try decoder.decode(ServerResponseDTO.self, from: data)
            let audioData = dto.audio.flatMap { Data(base64Encoded: $0) }
            return .response(text: dto.text, sessionId: dto.sessionId, audio: audioData)

        case "transcription":
            let dto = try decoder.decode(TranscriptionDTO.self, from: data)
            return .transcription(text: dto.text, sessionId: dto.sessionId)

        case "notification":
            let dto = try decoder.decode(NotificationDTO.self, from: data)
            return .notification(title: dto.title, body: dto.body, urgency: dto.urgency)

        case "voice_notification":
            let dto = try decoder.decode(VoiceNotificationDTO.self, from: data)
            guard let audioData = Data(base64Encoded: dto.audio) else {
                throw ServerMessageError.malformedPayload("Invalid base64 audio in voice_notification")
            }
            return .voiceNotification(title: dto.title, audio: audioData)

        case "error":
            let dto = try decoder.decode(ErrorDTO.self, from: data)
            return .error(text: dto.text, sessionId: dto.sessionId)

        default:
            throw ServerMessageError.unknownType(peek.type)
        }
    }
}
