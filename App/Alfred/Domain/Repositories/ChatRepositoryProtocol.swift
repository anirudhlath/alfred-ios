import Foundation
import AlfredKit

protocol ChatRepositoryProtocol: Sendable {
    func connect() async throws
    func disconnect()
    func send(text: String) async throws -> Message
    func send(audioData: Data, format: AudioFormat) async throws -> Message
    var messages: AsyncStream<Message> { get }
    var connectionState: AsyncStream<ConnectionState> { get }
}

enum AudioFormat: Sendable {
    case aac
    case wav
}
