struct ServerConfig: Sendable {
    var host: String
    var port: Int

    static let `default` = ServerConfig(host: "100.100.1.1", port: 8081)
}
