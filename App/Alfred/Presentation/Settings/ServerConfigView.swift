import SwiftUI

struct ServerConfigView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel = ServerConfigViewModel()

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Host (Tailscale IP)", text: $viewModel.host)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Port", text: $viewModel.port)
                    .keyboardType(.numberPad)
            }

            Section {
                Button("Test Connection") {
                    Task { await viewModel.testConnection() }
                }
                .disabled(viewModel.isTesting)

                if viewModel.isTesting {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Testing...")
                    }
                } else if let reachable = viewModel.isReachable {
                    HStack {
                        Image(systemName: reachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(reachable ? .green : .red)
                        Text(reachable ? "Connected" : "Unreachable")
                    }
                }
            }

            Section {
                Button("Save & Reconnect") {
                    viewModel.save()
                }
                .disabled(viewModel.host.isEmpty)
            }
        }
        .navigationTitle("Server Config")
        .onAppear {
            viewModel.configure(with: container)
        }
    }
}
