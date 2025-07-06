import SwiftUI

/// Reusable chat interface component
struct ChatInterfaceView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var scrollToBottom = false
    @Namespace private var bottomID
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.spacing) {
                        if viewModel.messages.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(viewModel.messages, id: \.id) { message in
                                ChatMessageRow(message: message)
                                    .id(message.id)
                            }
                        }
                        
                        // Anchor for scrolling to bottom
                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                    }
                    .padding(Theme.spacing)
                }
                .onChange(of: viewModel.messages.count) {
                    withAnimation(Theme.smoothAnimation) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
                .onChange(of: scrollToBottom) { _, shouldScroll in
                    if shouldScroll {
                        withAnimation(Theme.smoothAnimation) {
                            proxy.scrollTo(bottomID, anchor: .bottom)
                        }
                        scrollToBottom = false
                    }
                }
            }
            
            Divider()
            
            // Input area
            messageInputArea
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Theme.largeSpacing) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.tertiaryText)
            
            VStack(spacing: Theme.smallSpacing) {
                Text("Start a conversation")
                    .font(Theme.Typography.title)
                
                Text("I'm here to chat about your thoughts and reflections.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 500)
        .padding(.vertical, 60)
    }
    
    private var messageInputArea: some View {
        HStack(spacing: Theme.spacing) {
            HStack {
                TextField("Message Gemi...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.Typography.body)
                    .lineLimit(1...5)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if !NSEvent.modifierFlags.contains(.shift) {
                            sendMessage()
                        }
                    }
                    .disabled(viewModel.isLoading)
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .padding(Theme.spacing)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.cornerRadius)
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.isEmpty || viewModel.isLoading ? Color.secondary : Theme.Colors.primaryAccent)
            }
            .buttonStyle(.plain)
            .disabled(messageText.isEmpty || viewModel.isLoading)
        }
        .padding(Theme.spacing)
    }
    
    private func sendMessage() {
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        messageText = ""
        
        Task {
            await viewModel.sendMessage(message)
            scrollToBottom = true
            
            // Show error alert if needed
            if let error = viewModel.error {
                await showError(error)
            }
        }
    }
    
    @MainActor
    private func showError(_ error: Error) async {
        let alert = NSAlert()
        alert.messageText = "Chat Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Chat Message Row

struct ChatMessageRow: View {
    let message: ChatHistoryMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacing) {
            if message.role == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(Theme.Typography.body)
                    .padding(Theme.spacing)
                    .background(message.role == .user ? Theme.Colors.primaryAccent : Theme.Colors.cardBackground)
                    .foregroundColor(message.role == .user ? .white : Color.primary)
                    .cornerRadius(Theme.cornerRadius)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}