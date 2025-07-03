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
    @State private var showingMemoryInfo: Bool = false
    @State private var chatOffset: CGFloat = 500
    @State private var backdropOpacity: Double = 0
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(OnboardingState.self) private var onboardingState
    @FocusState private var isInputFocused: Bool
    
    // AI Service integration
    @State private var chatViewModel: ChatViewModel
    @State private var ollamaService: OllamaService
    
    // Presentation style
    enum PresentationStyle {
        case modal      // Presented as sheet/modal with fixed width
        case fullWidth  // Presented in content area with full width
    }
    var presentationStyle: PresentationStyle
    
    // MARK: - Initialization
    
    init(isPresented: Binding<Bool>, presentationStyle: PresentationStyle = .modal, ollamaService: OllamaService? = nil) {
        self._isPresented = isPresented
        self.presentationStyle = presentationStyle
        let service = ollamaService ?? OllamaService()
        self._ollamaService = State(initialValue: service)
        self._chatViewModel = State(initialValue: ChatViewModel(ollamaService: service))
    }
    
    // MARK: - Body
    
    var body: some View {
        switch presentationStyle {
        case .modal:
            modalPresentation
        case .fullWidth:
            fullWidthPresentation
        }
    }
    
    // MARK: - Modal Presentation (original sidebar style)
    
    @ViewBuilder
    private var modalPresentation: some View {
        ZStack {
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
            
            // Chat panel - properly floating with padding
            HStack {
                Spacer()
                
                if isPresented {
                    chatPanel
                        .padding(.trailing, 24)
                        .padding(.vertical, 24)
                        .offset(x: chatOffset)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
        }
        .onAppear {
            if isPresented {
                withAnimation(DesignSystem.Animation.cozySettle) {
                    chatOffset = 0
                    backdropOpacity = 1
                }
                
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
                chatViewModel.isChatVisible = true
            } else {
                withAnimation(DesignSystem.Animation.standard) {
                    chatOffset = 500
                    backdropOpacity = 0
                }
                chatViewModel.isChatVisible = false
            }
        }
    }
    
    // MARK: - Full Width Presentation (for sidebar selection)
    
    @ViewBuilder
    private var fullWidthPresentation: some View {
        GeometryReader { geometry in
            chatPanelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignSystem.Colors.backgroundPrimary)
        }
        .onAppear {
            isInputFocused = true
            chatViewModel.isChatVisible = true
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
                text: $chatViewModel.currentInput,
                onSend: sendMessage,
                onVoice: startVoiceInput
            )
            .focused($isInputFocused)
        }
    }
    
    @ViewBuilder
    private var messagesScrollView: some View {
        if chatViewModel.messages.isEmpty {
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
                        ForEach(chatViewModel.suggestedPrompts.prefix(3), id: \.self) { prompt in
                            Button(action: {
                                chatViewModel.useSuggestedPrompt(prompt)
                            }) {
                                SuggestionChip(
                                    text: prompt,
                                    icon: prompt.contains("today") ? "sun.max" : 
                                          prompt.contains("week") ? "calendar" : 
                                          "sparkles"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
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
                        ForEach(chatViewModel.messages) { message in
                            ChatMessageBubble(
                                message: message,
                                isLastMessage: chatViewModel.isLastMessage(message)
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .offset(x: message.isUser ? 20 : -20)),
                                removal: .opacity
                            ))
                        }
                        
                        if chatViewModel.isGenerating && !chatViewModel.streamingResponse.isEmpty {
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
                .onChange(of: chatViewModel.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        if let lastMessage = chatViewModel.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        } else if chatViewModel.isGenerating {
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
            .help("Close chat (Esc)")
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
                
                Text("Gemi is aware of \(12) memories")
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
    
    private func sendMessage() {
        Task {
            await chatViewModel.sendMessage()
        }
    }
    
    private func startVoiceInput() {
        // Voice input implementation - will be integrated with SpeechRecognitionService
    }
}

// MARK: - Chat Message Bubble

struct ChatMessageBubble: View {
    let message: ChatMessage
    let isLastMessage: Bool
    @State private var showTimestamp: Bool = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !message.isUser {
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
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Message content
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundStyle(message.isUser ? .white : (message.isError ? DesignSystem.Colors.error : .primary))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(message.isUser ? 
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primary,
                                        DesignSystem.Colors.primary.opacity(0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: message.isError ? [
                                        DesignSystem.Colors.error.opacity(0.1),
                                        DesignSystem.Colors.error.opacity(0.05)
                                    ] : [
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
                
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showTimestamp = hovering
                }
            }
            
            if message.isUser {
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
                .help("Voice input")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
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
        
        // Fix: Set text color explicitly for dark mode support
        textView.textColor = NSColor.labelColor
        
        // Fix: Configure text container properly
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
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
        
        // Fix: Ensure text color remains set for dark mode
        textView.textColor = NSColor.labelColor
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updateHeight(_ textView: NSTextView) {
        // Fix: Properly calculate height based on text content
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager else { return }
        
        // Force layout to get accurate measurements
        layoutManager.ensureLayout(for: textContainer)
        
        // Get the used rect for the text
        let usedRect = layoutManager.usedRect(for: textContainer)
        let textHeight = usedRect.height
        
        // Add padding for text container inset
        let totalHeight = textHeight + textView.textContainerInset.height * 2
        
        DispatchQueue.main.async {
            // Set height with min/max constraints
            height = max(40, min(totalHeight, 120))
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