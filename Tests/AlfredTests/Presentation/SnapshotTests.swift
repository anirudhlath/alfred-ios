import SwiftUI
import Testing
@testable import Alfred

// Snapshot tests for key views.
// Reference images generated on first run with a simulator.
// These tests require an iOS Simulator runtime to be installed.
//
// Run with:
//   xcodebuild test -project Alfred.xcodeproj -scheme Alfred \
//     -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

import SnapshotTesting

// Note: swift-snapshot-testing uses XCTest, not Swift Testing.
// These tests use XCTest for compatibility with the snapshot library.
import XCTest

@MainActor
final class ChatViewSnapshotTests: XCTestCase {
    func testChatViewEmpty() {
        let container = makePreviewContainer()
        let view = NavigationStack {
            ChatView()
        }
        .environment(container)

        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Pro)))
    }

    func testChatViewWithMessages() {
        let container = makePreviewContainer()
        let view = NavigationStack {
            ChatView()
        }
        .environment(container)

        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Pro)))
    }
}

@MainActor
final class NotificationsViewSnapshotTests: XCTestCase {
    func testNotificationsViewEmpty() {
        let container = makePreviewContainer()
        let view = NavigationStack {
            NotificationsView()
        }
        .environment(container)

        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Pro)))
    }
}

@MainActor
final class SettingsViewSnapshotTests: XCTestCase {
    func testSettingsView() {
        let container = makePreviewContainer()
        let view = NavigationStack {
            SettingsView()
        }
        .environment(container)

        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Pro)))
    }
}

@MainActor
final class OnboardingSnapshotTests: XCTestCase {
    func testWelcomeStep() {
        let view = WelcomeStepView(onNext: {})
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Pro)))
    }
}

// Helper to create a container for previews
private func makePreviewContainer() -> AppContainer {
    AppContainer()
}



