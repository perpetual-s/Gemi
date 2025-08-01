import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Main chat interface for conversations with Gemi
/// Rebuilt from scratch with proper layout and beautiful UI
struct GemiChatView: View {
    @StateObject private var viewModel = EnhancedChatViewModel()
    @StateObject private var attachmentManager = AttachmentManager.shared
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @Namespace private var bottomID
    @State private var showDictationTip = false
    @State private var showAttachmentMenu = false
    
    let contextEntry: JournalEntry?
    
    init(contextEntry: JournalEntry? = nil) {
        self.contextEntry = contextEntry
    }
    
    var body: some View {
        ZStack {
            // Show loading view when model is not connected
            if viewModel.connectionStatus != .connected {
                ModelLoadingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                // Main chat interface
                VStack(spacing: 0) {
                    // Header bar
                    chatHeader
                    
                    // Multimodal support notification - show when attachments are present
                    if viewModel.isMultimodalSupported && !attachmentManager.attachments.isEmpty {
                        MultimodalNotificationBanner()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Error notification
                    if viewModel.error != nil {
                        ErrorNotificationBanner(error: viewModel.error!) {
                            viewModel.error = nil
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Messages area
                    messagesScrollView
                    
                    // Attachment preview
                    AttachmentPreviewView(attachmentManager: attachmentManager)
                    
                    // Multimodal processing indicator
                    MultimodalProcessingView()
                    
                    // Progress indicator for processing attachments
                    AttachmentProgressView(attachmentManager: attachmentManager)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    
                    // Input area at bottom
                    messageInputArea
                }
                .background(Theme.Colors.windowBackground)
                .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                    return true
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            viewModel.loadMessages()
            viewModel.startConnectionMonitoring()
            
            // If we have a context entry, start the conversation about it
            if let entry = contextEntry {
                let contextMessage = """
                I'd like to discuss this journal entry with you:
                
                Title: \(entry.displayTitle)
                
                \(entry.content)
                
                Written on: \(entry.createdAt.formatted(date: .long, time: .shortened))
                \(entry.mood != nil ? "Mood: \(entry.mood!.emoji) \(entry.mood!.rawValue)" : "")
                """
                
                Task {
                    await viewModel.sendMessage(contextMessage)
                }
            }
            
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
        .overlay(
            // Dictation tip overlay
            Group {
                if showDictationTip {
                    ZStack {
                        // Background dimming
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showDictationTip = false
                                }
                            }
                        
                        // Dictation tip positioned above input area
                        VStack {
                            Spacer()
                            
                            DictationTipView {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showDictationTip = false
                                }
                            }
                            .padding(.bottom, 100) // Position above input area
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity),
                                removal: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity)
                            ))
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: showDictationTip)
                }
            }
        )
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack(spacing: 16) {
            
            // Title with attribution
            VStack(alignment: .leading, spacing: 2) {
                Text("Chat with Gemi")
                    .font(Theme.Typography.sectionHeader)
                
                HStack(spacing: 4) {
                    Text("Powered by Gemma 3n from Google DeepMind")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                    
                    if viewModel.isStreaming {
                        Text("• Thinking...")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Connection indicator
            connectionIndicator
            
            // New chat button
            Button {
                viewModel.startNewChat()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primaryAccent.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.Colors.primaryAccent)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
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
                .font(Theme.Typography.caption)
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
                LazyVStack(spacing: 12) {  // Use LazyVStack for better performance
                    if viewModel.messages.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 60)
                    } else {
                        // Messages start from top
                        messagesContent
                        
                        // Flexible spacer to push content up when there are few messages
                        Spacer(minLength: 0)
                    }
                    
                    // Anchor for scrolling to bottom
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)  // Better bounce behavior
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                // Scroll for new messages
                if newCount > oldCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
            }
            .onChange(of: viewModel.messages.last?.content) { _, _ in
                // Continuously scroll as content streams in
                if viewModel.isStreaming {
                    // Use no animation for smooth continuous scrolling during streaming
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
            .onAppear {
                // Initial scroll to bottom
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToBottom(proxy: proxy, animated: false)
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
            .id(message.id)  // Stable ID for each message
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8, anchor: message.role == .user ? .bottomTrailing : .bottomLeading)
                    .combined(with: .opacity),
                removal: .opacity
            ))
            .animation(viewModel.isStreaming ? nil : .easeOut(duration: 0.2), value: message.content)  // No animation during streaming for smooth scroll
        }
        
        if viewModel.isTyping {
            TypingIndicator()
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.scale.combined(with: .opacity))
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Logo with emoji-like appearance
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.primaryAccent.opacity(0.1), Theme.Colors.primaryAccent.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Text("💬")
                    .font(.system(size: 56))
            }
            .padding(.bottom, 8)
            
            VStack(spacing: 8) {
                Text("Your thoughts are safe here")
                    .font(Theme.Typography.largeTitle)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primary, Color.primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Share freely, nothing leaves your device")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                // Privacy-focused attribution - prominently placed
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("100% Private • Powered by Gemma 3n • No Cloud")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.primary.opacity(0.9), Color.primary.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.08))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.top, 4)
            }
            
            // Suggestions
            if !viewModel.suggestedPrompts.isEmpty {
                VStack(spacing: 12) {
                    Text("Start journaling:")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
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
                .opacity(0.5)
            
            HStack(spacing: 8) {
                // Refined Apple-style input field with integrated elements
                HStack(spacing: 6) {
                    // Combined attachment menu button
                    CombinedAttachmentButton(
                        attachmentManager: attachmentManager,
                        showDictationTip: $showDictationTip
                    )
                    
                    // Compact text field
                    ZStack(alignment: .leading) {
                        // Subtle placeholder
                        if messageText.isEmpty && !isInputFocused {
                            Text("Message")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.tertiaryText.opacity(0.6))
                                .allowsHitTesting(false)
                        }
                        
                        // Minimal text field
                        TextField("", text: $messageText, axis: .vertical)
                            .font(Theme.Typography.body)
                            .focused($isInputFocused)
                            .textFieldStyle(.plain)
                            .lineLimit(1...5)
                            .frame(minHeight: 20)
                            .fixedSize(horizontal: false, vertical: true)
                            .onSubmit {
                                if canSendMessage {
                                    sendMessage()
                                }
                            }
                    }
                    .padding(.vertical, 7)
                    
                    // Send button appears when there's text
                    if !messageText.isEmpty {
                        sendButtonCompact
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.Colors.cardBackground.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(
                                    isInputFocused ? 
                                    Theme.Colors.primaryAccent.opacity(0.4) : 
                                    Theme.Colors.divider.opacity(0.3), 
                                    lineWidth: 1
                                )
                        )
                )
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: isInputFocused)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: !messageText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                    .opacity(0.98)
            )
        }
    }
    
    private var sendButtonRefined: some View {
        Button {
            sendMessage()
        } label: {
            ZStack {
                // Background circle with gradient
                Circle()
                    .fill(
                        canSendMessage ?
                        LinearGradient(
                            colors: [
                                Theme.Colors.primaryAccent,
                                Theme.Colors.primaryAccent.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.2),
                                Color.gray.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(
                        color: canSendMessage ? 
                            Theme.Colors.primaryAccent.opacity(0.3) : 
                            .clear,
                        radius: canSendMessage ? 4 : 0,
                        x: 0,
                        y: 2
                    )
                
                // Icon or loading indicator
                if viewModel.isStreaming {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.up")
                        .font(Theme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(canSendMessage ? 0 : -90))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canSendMessage)
                }
            }
            .scaleEffect(canSendMessage ? 1 : 0.85)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: canSendMessage)
        }
        .buttonStyle(.plain)
        .disabled(!canSendMessage)
        .opacity(messageText.isEmpty ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.15), value: messageText.isEmpty)
    }
    
    private var sendButtonCompact: some View {
        Button {
            sendMessage()
        } label: {
            ZStack {
                Circle()
                    .fill(canSendMessage ? Theme.Colors.primaryAccent : Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)
                
                if viewModel.isStreaming {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: "arrow.up")
                        .font(Theme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSendMessage)
        .keyboardShortcut(.return, modifiers: [])
    }
    
    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        !viewModel.isStreaming &&
        viewModel.connectionStatus == .connected
    }
    
    // MARK: - Connection Status Overlay
    
    
    // MARK: - Actions
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        // Get base64 images from attachments
        let images = attachmentManager.getBase64Images()
        
        messageText = ""
        
        // The ViewModel will handle attachments via MultimodalAIService
        Task {
            await viewModel.sendMessage(trimmedMessage, images: images.isEmpty ? nil : images)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // Handle images
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                    if let url = item as? URL {
                        Task {
                            do {
                                try await attachmentManager.addAttachment(from: url)
                            } catch {
                                print("Failed to add dropped image: \(error)")
                            }
                        }
                    } else if let data = item as? Data {
                        Task {
                            do {
                                if let image = NSImage(data: data) {
                                    try await attachmentManager.addImage(image, fileName: "Dropped Image.png")
                                }
                            } catch {
                                print("Failed to add dropped image: \(error)")
                            }
                        }
                    }
                }
            }
            // Handle file URLs
            else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let url = item as? URL {
                        Task {
                            do {
                                try await attachmentManager.addAttachment(from: url)
                            } catch {
                                print("Failed to add dropped file: \(error)")
                            }
                        }
                    }
                }
            }
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
                    .font(Theme.Typography.body)
                    .foregroundColor(.purple)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.purple.opacity(0.1)))
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Images if present
                if let images = message.images, !images.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, base64Image in
                            if let data = Data(base64Encoded: base64Image),
                               let image = NSImage(data: data) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 300, maxHeight: 300)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(message.role == .user ? Color.clear : Theme.Colors.divider.opacity(0.2), lineWidth: 0.5)
                                    )
                                    .contextMenu {
                                        Button("Copy Image") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setData(data, forType: .tiff)
                                        }
                                        Button("Save Image...") {
                                            saveImage(image)
                                        }
                                    }
                            }
                        }
                    }
                }
                
                // Message content with better streaming support
                if !message.content.isEmpty || isStreaming {
                    Group {
                        if isStreaming && message.content.isEmpty {
                            // Show placeholder while waiting for content
                            Text(" ")
                                .font(Theme.Typography.body)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        } else {
                            Text(message.content)
                                .font(Theme.Typography.body)
                                .foregroundColor(message.role == .user ? .white : .primary)
                                .lineSpacing(2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .background(bubbleBackground)
                    .cornerRadius(18)
                    .animation(nil, value: message.content)  // Disable animation for content changes
                }
                
                // Timestamp (on hover)
                if isHovered && !isStreaming {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.tertiaryText)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(maxWidth: 500, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .user {
                // User avatar
                Image(systemName: "person.fill")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryAccent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.Colors.primaryAccent.opacity(0.1)))
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .onHover { hovering in
            if !isStreaming {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
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
    
    private func saveImage(_ image: NSImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.png, UTType.jpeg]
        savePanel.nameFieldStringValue = "Gemi Image"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData) {
                    let imageData = savePanel.url?.pathExtension == "jpg" || savePanel.url?.pathExtension == "jpeg"
                        ? bitmapImage.representation(using: .jpeg, properties: [:])
                        : bitmapImage.representation(using: .png, properties: [:])
                    
                    try? imageData?.write(to: url)
                }
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
                    .font(Theme.Typography.caption)
                
                Text(prompt)
                    .font(Theme.Typography.body)
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

// MARK: - Visual Effect View
// Note: VisualEffectView has been moved to Components/VisualEffectView.swift

// MARK: - Combined Attachment Button

struct CombinedAttachmentButton: View {
    @ObservedObject var attachmentManager: AttachmentManager
    @Binding var showDictationTip: Bool
    @State private var showMenu = false
    @State private var showFilePicker = false
    
    var body: some View {
        Button {
            showMenu.toggle()
        } label: {
            ZStack {
                // Badge for attachment count
                if !attachmentManager.attachments.isEmpty {
                    Circle()
                        .fill(Theme.Colors.primaryAccent)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text("\(attachmentManager.attachments.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 8, y: -8)
                        .zIndex(1)
                }
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(
                        attachmentManager.attachments.isEmpty ?
                        Theme.Colors.secondaryText :
                        Theme.Colors.primaryAccent
                    )
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .buttonStyle(.plain)
        .help("Add attachment")
        .popover(isPresented: $showMenu, arrowEdge: .top) {
            AttachmentMenuView(
                attachmentManager: attachmentManager,
                showDictationTip: $showDictationTip,
                showFilePicker: $showFilePicker
            )
            .frame(width: 220)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.png, .jpeg, .gif, .heif, .webP, .bmp, .tiff],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                for url in urls {
                    do {
                        try await attachmentManager.addAttachment(from: url)
                    } catch {
                        print("Failed to add attachment: \(error)")
                    }
                }
            }
            
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }
}

// MARK: - Attachment Menu View

struct AttachmentMenuView: View {
    @ObservedObject var attachmentManager: AttachmentManager
    @Binding var showDictationTip: Bool
    @Binding var showFilePicker: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var hoveredOption: AttachmentOption?
    
    enum AttachmentOption: CaseIterable {
        case photo
        case voice
        
        var icon: String {
            switch self {
            case .photo: return "photo"
            case .voice: return "mic.fill"
            }
        }
        
        var title: String {
            switch self {
            case .photo: return "Photo"
            case .voice: return "Voice"
            }
        }
        
        var subtitle: String {
            switch self {
            case .photo: return "Add images"
            case .voice: return "Use dictation"
            }
        }
        
        var color: Color {
            switch self {
            case .photo: return .blue
            case .voice: return .orange
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(AttachmentOption.allCases, id: \.self) { option in
                AttachmentOptionButton(
                    option: option,
                    isHovered: hoveredOption == option,
                    action: {
                        handleSelection(option)
                    }
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hoveredOption = hovering ? option : nil
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Colors.windowBackground)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
    }
    
    private func handleSelection(_ option: AttachmentOption) {
        switch option {
        case .photo:
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showFilePicker = true
            }
            
        case .voice:
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showDictationTip = true
            }
        }
    }
}

// MARK: - Attachment Option Button

struct AttachmentOptionButton: View {
    let option: AttachmentMenuView.AttachmentOption
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(option.color.opacity(isHovered ? 0.15 : 0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: option.icon)
                        .font(.system(size: 16))
                        .foregroundColor(option.color)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(Theme.Typography.body)
                        .foregroundColor(.primary)
                    
                    Text(option.subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.tertiaryText)
                    .opacity(isHovered ? 1 : 0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Theme.Colors.cardBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dictation Tip View

struct DictationTipView: View {
    let onDismiss: () -> Void
    @State private var hoveredButton = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Instruction with icon
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Dictation")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Press **Fn** key twice to start dictating")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            Divider()
                .opacity(0.5)
            
            // Alternative method
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Settings")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Keyboard → Dictation")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            // Got it button
            Button(action: onDismiss) {
                HStack {
                    Spacer()
                    Text("Got it")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(hoveredButton ? Theme.Colors.primaryAccent : Theme.Colors.primaryAccent.opacity(0.9))
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    hoveredButton = hovering
                }
            }
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Colors.windowBackground)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Preview

struct GemiChatView_Previews: PreviewProvider {
    static var previews: some View {
        GemiChatView()
            .frame(width: 800, height: 600)
    }
}
