import SwiftUI

struct NotificationRowView: View {
    let notification: AppNotification
    var isPlaying = false
    var onPlayAudio: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            urgencyIcon
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                if let body = notification.body {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(notification.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if notification.audio != nil {
                    Button {
                        onPlayAudio?()
                    } label: {
                        Image(systemName: isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var urgencyIcon: some View {
        switch notification.urgency {
        case .urgent:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .important:
            Image(systemName: "bell.fill")
                .foregroundStyle(.orange)
        case .informational:
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
        }
    }
}
