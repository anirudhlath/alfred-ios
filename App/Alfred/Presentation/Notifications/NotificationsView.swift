import SwiftUI

struct NotificationsView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        Group {
            if viewModel.notifications.isEmpty {
                emptyState
            } else {
                notificationList
            }
        }
        .navigationTitle("Notifications")
        .onAppear {
            viewModel.configure(with: container)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Notifications",
            systemImage: "bell.slash",
            description: Text("Notifications from Alfred will appear here")
        )
    }

    private var notificationList: some View {
        List {
            ForEach(viewModel.groupedByDate, id: \.0) { dateString, items in
                Section(dateString) {
                    ForEach(items) { notification in
                        NotificationRowView(
                            notification: notification,
                            isPlaying: viewModel.playingNotificationId == notification.id,
                            onPlayAudio: { viewModel.playAudio(notification) }
                        )
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.dismiss(notification)
                                } label: {
                                    Label("Dismiss", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
