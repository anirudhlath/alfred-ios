import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel = SettingsViewModel()
    @State private var selectedIntegration: Integration?

    var body: some View {
        List {
            Section("Server Connection") {
                NavigationLink {
                    ServerConfigView()
                } label: {
                    Label("Server", systemImage: "server.rack")
                }
            }

            Section("Integrations") {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.integrations.isEmpty {
                    Text("No integrations available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.integrations) { integration in
                        Button {
                            selectedIntegration = integration
                        } label: {
                            HStack {
                                Text(integration.name.capitalized)
                                Spacer()
                                if integration.configured {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }

            Section("Notifications") {
                Toggle("Push Notifications", isOn: Binding(
                    get: { viewModel.pushNotificationsEnabled },
                    set: { viewModel.togglePushNotifications(enabled: $0) }
                ))
            }

            Section("Session") {
                Button("Clear Session", role: .destructive) {
                    viewModel.clearSession()
                }
            }

            Section("App") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            viewModel.configure(with: container)
        }
        .task {
            await viewModel.loadIntegrations()
        }
        .sheet(item: $selectedIntegration) { integration in
            NavigationStack {
                IntegrationDetailView(
                    integration: integration,
                    onSave: { fields in
                        try await viewModel.saveCredentials(
                            integration: integration.name,
                            fields: fields
                        )
                    },
                    onDelete: {
                        try await viewModel.deleteCredentials(integration: integration.name)
                    }
                )
            }
        }
    }
}
