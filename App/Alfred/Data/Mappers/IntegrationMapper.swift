import Foundation
import AlfredKit

enum IntegrationMapper {
    static func toDomain(from dto: IntegrationDTO) -> Integration {
        let fields = dto.schema.fields.map { key, fieldDTO in
            CredentialField(
                key: key,
                label: fieldDTO.label,
                type: fieldDTO.type == "password" ? .password : .text,
                required: fieldDTO.required
            )
        }
        let allConfigured = !dto.configured.isEmpty && dto.configured.values.allSatisfy { $0 }
        return Integration(
            name: dto.name,
            description: dto.description ?? "",
            configured: allConfigured,
            schema: fields
        )
    }
}
