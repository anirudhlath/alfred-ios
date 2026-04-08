import Foundation
import AlfredKit

enum OnboardingMapper {
    static func toDTO(from preferences: UserPreferences) -> OnboardingDTO {
        OnboardingDTO(
            wakeTime: preferences.wakeTime,
            workAddress: preferences.workAddress,
            dietaryRestrictions: preferences.dietaryRestrictions,
            proactivityLevel: preferences.proactivityLevel.rawValue,
            guestControls: preferences.guestControls.isEmpty ? nil : preferences.guestControls
        )
    }
}
