struct UserPreferences: Sendable {
    var wakeTime: String?
    var workAddress: String?
    var dietaryRestrictions: String?
    var proactivityLevel: ProactivityLevel
    var guestControls: [String]

    enum ProactivityLevel: String, Sendable {
        case opinionated
        case moderate
        case conservative
    }

    static let `default` = UserPreferences(
        wakeTime: nil,
        workAddress: nil,
        dietaryRestrictions: nil,
        proactivityLevel: .moderate,
        guestControls: []
    )
}
