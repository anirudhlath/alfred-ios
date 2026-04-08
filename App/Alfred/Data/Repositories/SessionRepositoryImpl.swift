import Foundation

final class SessionRepositoryImpl: SessionRepositoryProtocol, Sendable {
    private enum Keys {
        static let sessionId = "alfred_session_id"
        static let serverHost = "alfred_server_host"
        static let serverPort = "alfred_server_port"
    }

    func saveSessionId(_ id: String) {
        KeychainStore.save(key: Keys.sessionId, value: id)
    }

    func restoreSessionId() -> String? {
        KeychainStore.load(key: Keys.sessionId)
    }

    func clearSession() {
        KeychainStore.delete(key: Keys.sessionId)
    }

    func saveServerConfig(_ config: ServerConfig) {
        KeychainStore.save(key: Keys.serverHost, value: config.host)
        KeychainStore.save(key: Keys.serverPort, value: String(config.port))
    }

    func restoreServerConfig() -> ServerConfig? {
        guard let host = KeychainStore.load(key: Keys.serverHost),
              let portStr = KeychainStore.load(key: Keys.serverPort),
              let port = Int(portStr) else { return nil }
        return ServerConfig(host: host, port: port)
    }
}
