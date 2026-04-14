import Foundation
import SwiftUI

@Observable
@MainActor
final class ServerConfigViewModel {
    var host: String = ""
    var port: String = "8081"
    var isReachable: Bool?
    var isTesting = false
    private var container: AppContainer?

    func configure(with container: AppContainer) {
        self.container = container
        let config = container.sessionRepository.restoreServerConfig() ?? ServerConfig.default
        host = config.host
        port = String(config.port)
    }

    func save() {
        guard let container, let portInt = Int(port) else { return }
        let config = ServerConfig(host: host, port: portInt)
        container.reconfigure(with: config)
        container.startNotificationObservation()
    }

    func testConnection() async {
        isTesting = true
        isReachable = nil
        guard let container else {
            isTesting = false
            return
        }
        let result = await container.restClient.healthCheck()
        isReachable = result
        isTesting = false
    }
}
