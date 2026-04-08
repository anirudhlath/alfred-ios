import SwiftUI

struct InputBarView: View {
    @Binding var text: String
    let isRecording: Bool
    let onSend: () -> Void
    let onToggleRecording: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleRecording) {
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.title3)
                    .foregroundStyle(isRecording ? .red : .blue)
            }

            TextField("Message Alfred...", text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
                .onSubmit(onSend)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
