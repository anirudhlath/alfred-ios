import Foundation
import Testing
@testable import Alfred

// Reuse mocks from UseCaseTests — test targets compile all test sources together,
// so MockChatRepository, MockMessageStore, MockSessionRepository are accessible.

@Test @MainActor func chatViewModelStartsDisconnected() {
    let vm = ChatViewModel()
    #expect(vm.connectionState == .disconnected)
    #expect(vm.messages.isEmpty)
    #expect(vm.isWaiting == false)
    #expect(vm.isRecording == false)
}

@Test @MainActor func chatViewModelSendClearsInput() {
    let vm = ChatViewModel()
    vm.inputText = "  "
    vm.send()
    // Should not crash with no container, and should not set isWaiting for empty text
    #expect(vm.isWaiting == false)
}

@Test @MainActor func chatViewModelSendIgnoresEmptyText() {
    let vm = ChatViewModel()
    vm.inputText = ""
    vm.send()
    #expect(vm.isWaiting == false)
    #expect(vm.messages.isEmpty)
}
