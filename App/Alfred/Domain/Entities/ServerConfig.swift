struct ServerConfig: Sendable {
    var host: String
    var port: Int

    #if DEBUG
    static let `default` = ServerConfig(host: "localhost", port: 8081)
    #else
    static let `default` = ServerConfig(host: "100.100.1.1", port: 8081)
    #endif
}
