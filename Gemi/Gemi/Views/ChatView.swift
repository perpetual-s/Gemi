//
//  ChatView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

/// A beautiful AI chat interface that integrates naturally with the diary
struct ChatView: View {
    
    // MARK: - Properties
    
    @Binding var isPresented: Bool
    @State private var messages: [ChatMessage] = []
    @State private var isTyping: Bool = false
    @State private var memoryCount: Int = 12
    @State private var inputText: String = ""
    @State private var showingMemoryInfo: Bool = false
    @State private var chatOffset: CGFloat = 500
    @State private var backdropOpacity: Double = 0
    @State private var hasShownWelcome: Bool = false
    @State private var isFirstTimeUser: Bool = true
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(OnboardingState.self) private var onboardingState
    @FocusState private var isInputFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Backdrop blur
            if isPresented {
                Color.black
                    .opacity(backdropOpacity * 0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissChat()
                    }
                    .transition(.opacity)
            }
            
            // Chat panel
            if isPresented {
                chatPanel
                    .offset(x: chatOffset)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .onAppear {
            if isPresented {
                withAnimation(DesignSystem.Animation.cozySettle) {
                    chatOffset = 0
                    backdropOpacity = 1
                }
                
                // Add welcome message
                addWelcomeMessage()
                // Haptic feedback on chat open
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                withAnimation(DesignSystem.Animation.cozySettle) {
                    chatOffset = 0
                    backdropOpacity = 1
                }
                isInputFocused = true
            } else {
                withAnimation(DesignSystem.Animation.standard) {
                    chatOffset = 500
                    backdropOpacity = 0
                }
            }
        }
    }
    
    // MARK: - Chat Panel
    
    @ViewBuilder
    private var chatPanel: some View {
        chatPanelContent
            .frame(width: 420)
            .frame(maxHeight: .infinity)
            .background(chatPanelBackground)
            .overlay(chatPanelBorder)
    }
    
    @ViewBuilder
    private var chatPanelContent: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            Divider()
                .opacity(0.1)
            
            // Memory indicator
            memoryIndicator
            
            // Messages
            messagesScrollView
            
            // Input area
            ChatInputView(
                text: $inputText,
                onSend: sendMessage,
                onVoice: startVoiceInput
            )
            .focused($isInputFocused)
        }
    }
    
    @ViewBuilder
    private var messagesScrollView: some View {
        if messages.isEmpty && !hasShownWelcome {
            // Empty state
            VStack(spacing: 24) {
                Spacer()
                
                // Illustration
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.1),
                                    Color(red: 0.48, green: 0.70, blue: 0.90).opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.36, green: 0.61, blue: 0.84),
                                    Color(red: 0.48, green: 0.70, blue: 0.90)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 12) {
                    Text("Start a conversation")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text("I'm here to help you reflect on your thoughts,\nexplore your feelings, and remember what matters.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                VStack(spacing: 12) {
                    Text("Try asking me:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        SuggestionChip(text: "How was my week?", icon: "calendar")
                        SuggestionChip(text: "What patterns do you see in my writing?", icon: "chart.line.uptrend.xyaxis")
                        SuggestionChip(text: "Help me reflect on today", icon: "sun.max")
                    }
                }
                
                Spacer()
            }
            .padding(40)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                removal: .opacity
            ))
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            MessageBubble(message: message)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .offset(x: message.role == .user ? 20 : -20)),
                                    removal: .opacity
                                ))
                        }
                        
                        if isTyping {
                            TypingIndicator()
                                .id("typing")
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 60)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        if let lastMessage = messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        } else if isTyping {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var chatPanelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.1), radius: 20, x: -5, y: 0)
            .shadow(color: .black.opacity(0.06), radius: 40, x: -10, y: 0)
    }
    
    @ViewBuilder
    private var chatPanelBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
    }
    
    // MARK: - Header
    
    @ViewBuilder
    private var chatHeader: some View {
        HStack(spacing: 12) {
            // Gemi avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.36, green: 0.61, blue: 0.84),
                                Color(red: 0.48, green: 0.70, blue: 0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Gemi")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("Your AI journal companion")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Close button
            Button {
                dismissChat()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .tooltip("Close chat (Esc)", edge: .bottom)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Memory Indicator
    
    @ViewBuilder
    private var memoryIndicator: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showingMemoryInfo.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .medium))
                
                Text("Gemi is aware of \(memoryCount) memories")
                    .font(.system(size: 13, weight: .medium))
                
                Image(systemName: showingMemoryInfo ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        
        if showingMemoryInfo {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent memories:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    MemoryItem(text: "Your morning reflection about gratitude")
                    MemoryItem(text: "The peaceful walk in the park last week")
                    MemoryItem(text: "Your thoughts on personal growth")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .transition(.asymmetric(
                insertion: .push(from: .top).combined(with: .opacity),
                removal: .push(from: .bottom).combined(with: .opacity)
            ))
        }
    }
    
    // MARK: - Methods
    
    private func dismissChat() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
    
    private func addWelcomeMessage() {
        guard !hasShownWelcome else { return }
        hasShownWelcome = true
        
        let welcome = ChatMessage(
            role: .assistant,
            content: "Hello! I'm here whenever you want to talk about your thoughts, reflect on your entries, or just have a friendly conversation. What's on your mind?",
            timestamp: Date()
        )
        messages.append(welcome)
        
        // Coach marks are handled by the view modifier
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(
            role: .user,
            content: inputText,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Clear input
        let messageToSend = inputText
        inputText = ""
        
        // Show typing indicator
        withAnimation(.easeIn(duration: 0.2)) {
            isTyping = true
        }
        
        // Simulate AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.2)) {
                isTyping = false
                
                let response = ChatMessage(
                    role: .assistant,
                    content: generateResponse(for: messageToSend),
                    timestamp: Date()
                )
                messages.append(response)
            }
        }
    }
    
    private func startVoiceInput() {
        // Voice input implementation
    }
    
    private func generateResponse(for message: String) -> String {
        // This would connect to the actual AI service
        return "I understand you're thinking about \"\(message)\". That's a really interesting perspective. Would you like to explore this further in your journal?"
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let content: String
    let timestamp: Date
    var referencedEntry: JournalEntry?
}

enum ChatRole {
    case user
    case assistant
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showTimestamp: Bool = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                // Gemi avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.8),
                                Color(red: 0.48, green: 0.70, blue: 0.90).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    )
            } else {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message content
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(message.role == .user ? 
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.36, green: 0.61, blue: 0.84),
                                        Color(red: 0.42, green: 0.67, blue: 0.88)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [
                                        Color.primary.opacity(0.06),
                                        Color.primary.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                
                // Timestamp (on hover)
                if showTimestamp {
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
                
                // Referenced entry preview
                if let entry = message.referencedEntry {
                    EntryPreview(entry: entry)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showTimestamp = hovering
                }
            }
            
            if message.role == .user {
                // User avatar placeholder
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String("U"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    )
            } else {
                Spacer()
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animationOffsets: [CGFloat] = [0, 0, 0]
    @State private var bubbleScale: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Gemi avatar with pulse
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.2),
                            Color(red: 0.48, green: 0.70, blue: 0.90).opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.6))
                )
                // Pulse animation
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.8),
                                    Color(red: 0.48, green: 0.70, blue: 0.90).opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffsets[index])
                        .scaleEffect(1 + animationOffsets[index] * -0.1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .scaleEffect(bubbleScale)
            .opacity(bubbleScale)
            
            Spacer()
        }
        .onAppear {
            withAnimation(DesignSystem.Animation.playfulBounce) {
                bubbleScale = 1
            }
            
            for index in 0..<3 {
                withAnimation(
                    Animation.easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15)
                ) {
                    animationOffsets[index] = -6
                }
            }
        }
    }
}

// MARK: - Memory Item

struct MemoryItem: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 4, height: 4)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Entry Preview

struct EntryPreview: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 11))
                
                Text("From your journal")
                    .font(.system(size: 11, weight: .medium))
                
                Text("·")
                
                Text(entry.date, style: .date)
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            
            Text(entry.content)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.04))
                )
        }
    }
}

// MARK: - Chat Input View

struct ChatInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    let onVoice: () -> Void
    
    @State private var textEditorHeight: CGFloat = 40
    @State private var sendButtonScale: CGFloat = 1.0
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Text input
            HStack(alignment: .bottom, spacing: 8) {
                // Expanding text editor
                ResizableTextEditor(
                    text: $text,
                    height: $textEditorHeight,
                    isFocused: $isFocused
                )
                .frame(height: min(textEditorHeight, 120))
                
                // Voice input button
                Button(action: onVoice) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .tooltip("Voice input", edge: .top)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
            )
            
            // Send button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    sendButtonScale = 0.8
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        sendButtonScale = 1.0
                    }
                    onSend()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.36, green: 0.61, blue: 0.84),
                                    Color(red: 0.42, green: 0.67, blue: 0.88)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(sendButtonScale)
                .opacity(text.isEmpty ? 0.5 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: text.isEmpty)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(text.isEmpty)
        }
        .padding(16)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider()
                        .opacity(0.1)
                }
        )
    }
}

// MARK: - Resizable Text Editor

struct ResizableTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    @FocusState.Binding var isFocused: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 15)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            textView.string = text
            updateHeight(textView)
        }
        
        if isFocused && textView.window?.firstResponder != textView {
            textView.window?.makeFirstResponder(textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updateHeight(_ textView: NSTextView) {
        textView.textContainer?.containerSize = CGSize(width: textView.frame.width, height: .greatestFiniteMagnitude)
        textView.sizeToFit()
        let newHeight = textView.frame.height
        DispatchQueue.main.async {
            height = max(40, min(newHeight + 16, 120))
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: ResizableTextEditor
        
        init(_ parent: ResizableTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.updateHeight(textView)
        }
    }
}

// MARK: - Suggestion Chip

struct SuggestionChip: View {
    let text: String
    let icon: String
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.61, blue: 0.84),
                            Color(red: 0.48, green: 0.70, blue: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primary.opacity(isHovering ? 0.08 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.36, green: 0.61, blue: 0.84).opacity(isHovering ? 0.3 : 0.1),
                                    Color(red: 0.48, green: 0.70, blue: 0.90).opacity(isHovering ? 0.3 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.2), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Floating Action Button

struct ChatFloatingActionButton: View {
    let action: () -> Void
    @State private var isHovered: Bool = false
    @State private var pulseAnimation: Bool = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.36, green: 0.61, blue: 0.84),
                                Color(red: 0.42, green: 0.67, blue: 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                // Pulse animation
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 56, height: 56)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0 : 1)
                    .animation(
                        Animation.easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: pulseAnimation
                    )
                
                // Icon
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isHovered ? 10 : 0))
            }
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .shadow(
                color: Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.4),
                radius: isHovered ? 16 : 12,
                x: 0,
                y: isHovered ? 8 : 6
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            pulseAnimation = true
        }
    }
}

// MARK: - Preview

#Preview("Chat View") {
    @Previewable @State var isPresented = true
    
    return ZStack {
        // Background content
        Rectangle()
            .fill(Color(red: 0.96, green: 0.95, blue: 0.94))
            .overlay(
                VStack {
                    Text("Main Content")
                        .font(.largeTitle)
                    Text("This would be your journal")
                }
            )
        
        ChatView(isPresented: $isPresented)
    }
    .frame(width: 1200, height: 800)
}

#Preview("Floating Action Button") {
    ChatFloatingActionButton {
        print("Chat activated")
    }
    .padding(40)
    .background(Color(red: 0.96, green: 0.95, blue: 0.94))
}