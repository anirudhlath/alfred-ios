struct Integration: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let description: String
    let configured: Bool
    let schema: [CredentialField]
}

struct CredentialField: Sendable {
    let key: String
    let label: String
    let type: FieldType
    let required: Bool

    enum FieldType: Sendable {
        case text
        case password
    }
}
