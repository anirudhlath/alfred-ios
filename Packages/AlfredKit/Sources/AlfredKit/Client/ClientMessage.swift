import Foundation

/// Messages the iOS client sends to the Alfred server.
public enum ClientMessage: Sendable {
    case text(content: String, identity: String, channel: String = "ios")
    case audio(data: Data, mimeType: String, identity: String, channel: String = "ios")

    /// Encode to JSON Data for sending over WebSocket.
    public func encode(sessionId: String?) throws -> Data {
        let encoder = JSONEncoder()
        switch self {
        case .text(let content, let identity, let channel):
            let dto = TextMessageDTO(content: content, identity: identity, channel: channel, sessionId: sessionId)
            return try encoder.encode(dto)
        case .audio(let data, let mimeType, let identity, let channel):
            let base64 = data.base64EncodedString()
            let dataUrl = "data:\(mimeType);base64,\(base64)"
            let dto = AudioMessageDTO(content: dataUrl, identity: identity, channel: channel)
            return try encoder.encode(dto)
        }
    }
}
