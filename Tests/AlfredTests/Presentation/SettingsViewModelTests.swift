import Foundation
import Testing
@testable import Alfred

@Test @MainActor func settingsViewModelStartsWithPushEnabled() {
    let vm = SettingsViewModel()
    #expect(vm.pushNotificationsEnabled == true)
    #expect(vm.integrations.isEmpty)
    #expect(vm.isLoading == false)
}

@Test @MainActor func settingsViewModelClearSessionWithoutContainerDoesNotCrash() {
    let vm = SettingsViewModel()
    vm.clearSession()
    // No crash = success
}

@Test @MainActor func settingsViewModelTogglePushOffWithoutContainerDoesNotCrash() {
    let vm = SettingsViewModel()
    vm.togglePushNotifications(enabled: false)
    #expect(vm.pushNotificationsEnabled == false)
}

@Test @MainActor func settingsViewModelTogglePushUpdatesState() {
    let vm = SettingsViewModel()
    vm.togglePushNotifications(enabled: false)
    #expect(vm.pushNotificationsEnabled == false)

    vm.togglePushNotifications(enabled: true)
    #expect(vm.pushNotificationsEnabled == true)
}
