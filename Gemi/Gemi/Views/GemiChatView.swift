import SwiftUI

/// Main chat interface for conversations with Gemi
/// Rebuilt from scratch with proper layout and beautiful UI
struct GemiChatView: View {
    @StateObject private var viewModel = EnhancedChatViewModel()
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @Namespace private var bottomID
    
    var body: some View {
        ZStack {
            // Main chat interface
            VStack(spacing: 0) {
                // Header bar
                chatHeader
                
                // Messages area
                messagesScrollView
                
                // Input area at bottom
                messageInputArea
            }
            .background(Theme.Colors.windowBackground)
            
            // Connection status overlay
            if viewModel.connectionStatus != .connected {
                connectionStatusOverlay
            }
        }
        .onAppear {
            viewModel.loadMessages()
            viewModel.startConnectionMonitoring()
            // Focus input field on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isInputFocused = true
            }
        }
        .onDisappear {
            viewModel.saveMessages()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            viewModel.saveMessages()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            viewModel.saveMessages()
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack(spacing: 12) {
            
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text("Chat with Gemi")
                    .font(.system(size: 16, weight: .semibold))
                
                if viewModel.isStreaming {
                    Text("Thinking...")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            // Connection indicator
            connectionIndicator
            
            // New chat button
            Button {
                viewModel.startNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    private var connectionIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
                .overlay {
                    if viewModel.connectionStatus == .connecting {
                        Circle()
                            .stroke(connectionStatusColor, lineWidth: 2)
                            .scaleEffect(2)
                            .opacity(0)
                            .animation(
                                .easeOut(duration: 1)
                                .repeatForever(autoreverses: false),
                                value: viewModel.connectionStatus
                            )
                    }
                }
            
            Text(connectionStatusText)
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(connectionStatusColor.opacity(0.1))
        )
    }
    
    private var connectionStatusColor: Color {
        switch viewModel.connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .red
        }
    }
    
    private var connectionStatusText: String {
        switch viewModel.connectionStatus {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Offline"
        }
    }
    
    // MARK: - Messages Area
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                            .frame(maxHeight: .infinity)
                    } else {
                        messagesContent
                    }
                    
                    // Spacer for bottom padding
                    Color.clear
                        .frame(height: 20)
                        .id(bottomID)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }
    
    @ViewBuilder
    private var messagesContent: some View {
        ForEach(viewModel.messages) { message in
            MessageBubble(
                message: message,
                isStreaming: viewModel.isStreaming && message.id == viewModel.messages.last?.id
            )
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8, anchor: message.role == .user ? .bottomTrailing : .bottomLeading)
                    .combined(with: .opacity),
                removal: .opacity
            ))
        }
        
        if viewModel.isTyping {
            TypingIndicator()
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.scale.combined(with: .opacity))
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Logo
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Colors.primaryAccent, Theme.Colors.primaryAccent.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 8)
            
            VStack(spacing: 8) {
                Text("Welcome to Gemi")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                
                Text("Your thoughtful AI companion")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            // Suggestions
            if !viewModel.suggestedPrompts.isEmpty {
                VStack(spacing: 12) {
                    Text("Try asking:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    ForEach(viewModel.suggestedPrompts, id: \.self) { prompt in
                        SuggestionChip(prompt: prompt) {
                            messageText = prompt
                            sendMessage()
                        }
                    }
                }
                .padding(.top, 16)
            }
        }
        .frame(maxWidth: 500)
    }
    
    // MARK: - Input Area
    
    private var messageInputArea: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .center, spacing: 12) {
                // Text input
                inputField
                
                // Send button
                sendButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
    
    private var inputField: some View {
        // Text field container with proper vertical alignment
        TextField("Message Gemi...", text: $messageText, axis: .vertical)
            .font(.system(size: 14))
            .focused($isInputFocused)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .lineLimit(1...5)
            .frame(minHeight: 32)  // Minimum height matching send button
            .frame(maxHeight: 100)  // Allow expansion for multi-line
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            )
            .animation(.easeInOut(duration: 0.1), value: messageText.contains("\n"))
    }
    
    private var sendButton: some View {
        Button {
            sendMessage()
        } label: {
            ZStack {
                if canSendMessage {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.primaryAccent, Theme.Colors.primaryAccent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                }
                
                if viewModel.isStreaming {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSendMessage)
        .scaleEffect(canSendMessage ? 1 : 0.9)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canSendMessage)
    }
    
    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        !viewModel.isStreaming &&
        viewModel.connectionStatus == .connected
    }
    
    // MARK: - Connection Status Overlay
    
    private var connectionStatusOverlay: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 16))
                
                Text("Ollama is not connected")
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                Button("Retry") {
                    viewModel.checkOllamaConnection()
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.primaryAccent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(16)
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        messageText = ""
        
        Task {
            await viewModel.sendMessage(trimmedMessage)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatHistoryMessage
    let isStreaming: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                // Assistant avatar
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.purple)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.purple.opacity(0.1)))
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message content
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .lineSpacing(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleBackground)
                    .cornerRadius(18)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Timestamp (on hover)
                if isHovered {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.tertiaryText)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(maxWidth: 500, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .user {
                // User avatar
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.primaryAccent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.Colors.primaryAccent.opacity(0.1)))
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private var bubbleBackground: some View {
        Group {
            if message.role == .user {
                LinearGradient(
                    colors: [Theme.Colors.primaryAccent, Theme.Colors.primaryAccent.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Theme.Colors.cardBackground
            }
        }
    }
}

// MARK: - Supporting Views

struct SuggestionChip: View {
    let prompt: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                
                Text(prompt)
                    .font(.system(size: 14))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isHovered ? Theme.Colors.primaryAccent.opacity(0.1) : Theme.Colors.cardBackground)
                    .overlay(
                        Capsule()
                            .stroke(Theme.Colors.primaryAccent.opacity(isHovered ? 0.5 : 0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(Theme.Colors.primaryAccent)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Theme.Colors.secondaryText)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.1),
                        value: animationOffset
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(18)
        .onAppear {
            animationOffset = -4
        }
    }
}

// MARK: - Preview

struct GemiChatView_Previews: PreviewProvider {
    static var previews: some View {
        GemiChatView()
            .frame(width: 800, height: 600)
    }
}