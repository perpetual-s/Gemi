import SwiftUI

/// Main chat interface for conversations with Gemi
struct GemiChatView: View {
    @StateObject private var viewModel = EnhancedChatViewModel()
    @State private var messageText = ""
    @State private var showingConversations = true
    @State private var isComposingLongMessage = false
    @FocusState private var isTextFieldFocused: Bool
    @Namespace private var bottomID
    
    var body: some View {
        HSplitView {
            sidebarSection
            mainChatSection
            contextPanelSection
        }
        .background(Theme.Colors.windowBackground)
        .onAppear {
            isTextFieldFocused = true
            viewModel.checkOllamaConnection()
        }
    }
    
    @ViewBuilder
    private var sidebarSection: some View {
        if showingConversations {
            ConversationSidebar(viewModel: viewModel)
                .frame(width: 250)
                .transition(.move(edge: .leading))
        }
    }
    
    @ViewBuilder
    private var mainChatSection: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider()
            messagesArea
            Divider()
            enhancedInputArea
        }
    }
    
    @ViewBuilder
    private var contextPanelSection: some View {
        if viewModel.showingContextPanel {
            ContextPanel(viewModel: viewModel)
                .frame(width: 300)
                .transition(.move(edge: .trailing))
        }
    }
    
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                messagesContent
                    .padding(Theme.spacing)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(Theme.smoothAnimation) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isTyping) { _, _ in
                if viewModel.isTyping {
                    withAnimation(Theme.smoothAnimation) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var messagesContent: some View {
        LazyVStack(spacing: Theme.spacing) {
            if viewModel.messages.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.messages) { message in
                    EnhancedMessageRow(
                        message: message,
                        isStreaming: viewModel.isStreaming && message.id == viewModel.messages.last?.id
                    )
                    .id(message.id)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            
            if viewModel.isTyping {
                TypingIndicator()
                    .transition(.scale.combined(with: .opacity))
            }
            
            Color.clear
                .frame(height: 1)
                .id(bottomID)
        }
    }
    
    private var chatHeader: some View {
        HStack {
            Button {
                withAnimation(Theme.smoothAnimation) {
                    showingConversations.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.plain)
            
            Text(viewModel.currentConversation?.title ?? "Chat with Gemi")
                .font(Theme.Typography.headline)
            
            Spacer()
            
            // Connection status
            ConnectionStatusBadge(status: viewModel.connectionStatus)
            
            Button {
                withAnimation(Theme.smoothAnimation) {
                    viewModel.showingContextPanel.toggle()
                }
            } label: {
                Image(systemName: "brain")
            }
            .buttonStyle(.plain)
            .help("Show context and memories")
        }
        .padding(Theme.spacing)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Theme.largeSpacing) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Colors.primaryAccent, Theme.Colors.primaryAccent.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: Theme.smallSpacing) {
                Text("Welcome to Gemi")
                    .font(Theme.Typography.largeTitle)
                
                Text("Your private AI companion for thoughtful journaling")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            // Suggested prompts
            VStack(spacing: Theme.smallSpacing) {
                Text("Try asking:")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
                
                ForEach(viewModel.suggestedPrompts, id: \.self) { prompt in
                    SuggestedPromptButton(prompt: prompt) {
                        messageText = prompt
                        sendMessage()
                    }
                }
            }
            .padding(.top, Theme.largeSpacing)
        }
        .frame(maxWidth: 600)
        .padding(.vertical, 60)
    }
    
    private var enhancedInputArea: some View {
        VStack(spacing: 0) {
            // Composing indicator
            if isComposingLongMessage {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(Theme.Colors.primaryAccent)
                    Text("Composing...")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, Theme.spacing)
                .padding(.vertical, Theme.smallSpacing)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            HStack(alignment: .bottom, spacing: Theme.spacing) {
                // Attachment button (future)
                Button {
                    // Future: Add image/file attachment
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .disabled(true)
                .opacity(0.5)
                
                // Input field
                VStack(alignment: .trailing, spacing: 4) {
                    TextView(
                        text: $messageText,
                        placeholder: "Message Gemi...",
                        isFirstResponder: isTextFieldFocused
                    )
                    .frame(minHeight: 24, maxHeight: 150)
                    .padding(Theme.smallSpacing)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.cornerRadius)
                    .onChange(of: messageText) { _, newValue in
                        isComposingLongMessage = newValue.count > 100
                    }
                    
                    if !messageText.isEmpty {
                        Text("\(messageText.count) characters")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                    }
                }
                
                // Send button
                SendButton(
                    isEnabled: !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isStreaming,
                    isLoading: viewModel.isStreaming
                ) {
                    sendMessage()
                }
            }
            .padding(Theme.spacing)
        }
        .background(Theme.Colors.windowBackground.opacity(0.95))
        .background(.ultraThinMaterial)
    }
    
    private func sendMessage() {
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        messageText = ""
        isComposingLongMessage = false
        
        Task {
            await viewModel.sendMessage(message)
            
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

// MARK: - Supporting Views

struct ConnectionStatusBadge: View {
    let status: EnhancedChatViewModel.ConnectionStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(statusColor.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .scaleEffect(status == .connecting ? 1.5 : 1)
                        .opacity(status == .connecting ? 0 : 1)
                        .animation(
                            status == .connecting ?
                                Animation.easeInOut(duration: 1).repeatForever(autoreverses: true) :
                                .default,
                            value: status
                        )
                )
            
            Text(statusText)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding(.horizontal, Theme.smallSpacing)
        .padding(.vertical, 4)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.smallCornerRadius)
    }
    
    private var statusColor: Color {
        switch status {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Offline"
        }
    }
}

struct SuggestedPromptButton: View {
    let prompt: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(prompt)
                .font(Theme.Typography.body)
                .padding(.horizontal, Theme.spacing)
                .padding(.vertical, Theme.smallSpacing)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .fill(isHovered ? Theme.Colors.primaryAccent.opacity(0.1) : Theme.Colors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .strokeBorder(Theme.Colors.primaryAccent.opacity(0.3), lineWidth: 1)
                        )
                )
                .scaleEffect(isHovered ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct SendButton: View {
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isEnabled ? Theme.Colors.primaryAccent : Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 36)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .scaleEffect(isEnabled ? 1 : 0.9)
        .animation(.easeInOut(duration: 0.1), value: isEnabled)
    }
}

struct TypingIndicator: View {
    @State private var animatingDot = 0
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Theme.Colors.secondaryText)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDot == index ? 1.3 : 1)
                    .animation(
                        Animation
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animatingDot
                    )
            }
        }
        .padding(Theme.spacing)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 60)
        .onAppear {
            animatingDot = 0
        }
    }
}

// MARK: - Text View for multiline input

struct TextView: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isFirstResponder: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 0, height: 4)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        
        if textView.string != text {
            textView.string = text
        }
        
        // NSTextView doesn't have placeholderString property
        // We'll handle placeholder display differently
        
        if isFirstResponder && !context.coordinator.hasResignedFirstResponder {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextView
        var hasResignedFirstResponder = false
        
        init(_ parent: TextView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Preview

struct GemiChatView_Previews: PreviewProvider {
    static var previews: some View {
        GemiChatView()
            .frame(width: 900, height: 600)
    }
}