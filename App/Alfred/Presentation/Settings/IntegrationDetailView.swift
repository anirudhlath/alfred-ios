import SwiftUI

struct IntegrationDetailView: View {
    let integration: Integration
    let onSave: ([String: String]) async throws -> Void
    let onDelete: () async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fieldValues: [String: String] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(integration.description) {
                ForEach(integration.schema, id: \.key) { field in
                    if field.type == .password {
                        SecureField(field.label, text: binding(for: field.key))
                    } else {
                        TextField(field.label, text: binding(for: field.key))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(isSaving || !hasRequiredFields)

                if integration.configured {
                    Button("Remove Credentials", role: .destructive) {
                        Task { await delete() }
                    }
                }
            }
        }
        .navigationTitle(integration.name.capitalized)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { fieldValues[key, default: ""] },
            set: { fieldValues[key] = $0 }
        )
    }

    private var hasRequiredFields: Bool {
        integration.schema
            .filter(\.required)
            .allSatisfy { !fieldValues[$0.key, default: ""].isEmpty }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await onSave(fieldValues)
            dismiss()
        } catch {
            errorMessage = "Failed to save credentials"
        }
        isSaving = false
    }

    private func delete() async {
        isSaving = true
        do {
            try await onDelete()
            dismiss()
        } catch {
            errorMessage = "Failed to remove credentials"
        }
        isSaving = false
    }
}
