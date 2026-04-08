import Foundation

/// Server connection configuration.
public struct ServerConfiguration: Sendable, Codable, Equatable {
    public let host: String
    public let port: Int

    public init(host: String, port: Int = 8081) {
        self.host = host
        self.port = port
    }

    public var baseURL: URL {
        URL(string: "http://\(host):\(port)")!
    }

    public var webSocketURL: URL {
        URL(string: "ws://\(host):\(port)/ws")!
    }
}
