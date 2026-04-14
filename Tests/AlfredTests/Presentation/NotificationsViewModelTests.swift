import Foundation
import Testing
@testable import Alfred

@Test @MainActor func notificationsViewModelStartsEmpty() {
    let vm = NotificationsViewModel()
    #expect(vm.notifications.isEmpty)
    #expect(vm.playingNotificationId == nil)
}

@Test @MainActor func notificationsViewModelDismissRemovesNotification() {
    let container = AppContainer()
    let vm = NotificationsViewModel()
    vm.configure(with: container)

    let notif = AppNotification(
        id: UUID(), title: "Test", body: "Body",
        urgency: .informational, timestamp: Date(), audio: nil
    )
    vm.notifications = [notif]

    vm.dismiss(notif)
    #expect(vm.notifications.isEmpty)
}

@Test @MainActor func notificationsViewModelGroupedByDateGroupsCorrectly() {
    let container = AppContainer()
    let vm = NotificationsViewModel()
    vm.configure(with: container)

    let now = Date()
    let notif1 = AppNotification(
        id: UUID(), title: "A", body: nil,
        urgency: .informational, timestamp: now, audio: nil
    )
    let notif2 = AppNotification(
        id: UUID(), title: "B", body: nil,
        urgency: .urgent, timestamp: now, audio: nil
    )
    vm.notifications = [notif1, notif2]

    let grouped = vm.groupedByDate
    #expect(grouped.count == 1)
    #expect(grouped.first?.1.count == 2)
}

@Test @MainActor func notificationsViewModelPlayAudioWithoutContainerDoesNotCrash() {
    let vm = NotificationsViewModel()
    let audioData = Data([0x01, 0x02])
    let notif = AppNotification(
        id: UUID(), title: "Voice", body: nil,
        urgency: .important, timestamp: Date(), audio: audioData
    )
    // Should not crash when no container is configured
    vm.playAudio(notif)
    #expect(vm.playingNotificationId == nil)
}

@Test @MainActor func notificationsViewModelPlayAudioIgnoresNilAudio() {
    let vm = NotificationsViewModel()
    let notif = AppNotification(
        id: UUID(), title: "Text", body: "No audio",
        urgency: .informational, timestamp: Date(), audio: nil
    )
    vm.playAudio(notif)
    #expect(vm.playingNotificationId == nil)
}
