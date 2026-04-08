protocol SessionRepositoryProtocol: Sendable {
    func saveSessionId(_ id: String)
    func restoreSessionId() -> String?
    func clearSession()
    func saveServerConfig(_ config: ServerConfig)
    func restoreServerConfig() -> ServerConfig?
}
