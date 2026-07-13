struct ServerConfig: Sendable {
    var host: String
    var port: Int

    #if DEBUG
    static let `default` = ServerConfig(host: "localhost", port: 8081)
    #else
    /// No default host in release builds — the user must set their server
    /// address in Settings → Server Config (Keychain config takes priority).
    static let `default` = ServerConfig(host: "", port: 8081)
    #endif
}
