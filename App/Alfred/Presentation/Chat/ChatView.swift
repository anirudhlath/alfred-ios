import SwiftUI

struct ChatView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            connectionBanner
            messageList
            if viewModel.isWaiting {
                TypingIndicatorView()
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            InputBarView(
                text: $viewModel.inputText,
                isRecording: viewModel.isRecording,
                onSend: { viewModel.send() },
                onToggleRecording: { viewModel.toggleRecording() }
            )
        }
        .navigationTitle("Alfred")
        .onAppear {
            viewModel.configure(with: container)
        }
    }

    @ViewBuilder
    private var connectionBanner: some View {
        switch viewModel.connectionState {
        case .disconnected:
            HStack {
                Image(systemName: "wifi.slash")
                Text("Disconnected")
                Spacer()
                Button("Reconnect") { viewModel.reconnect() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.red.opacity(0.1))
        case .connecting:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting...")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.yellow.opacity(0.1))
        case .connected:
            EmptyView()
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    }
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) {
                if let last = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Start a conversation")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Type a message or use voice input")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 80)
    }
}
