//
//  EnhancedChatView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import SwiftUI
import os.log

/// Enhanced chat view with full memory and context capabilities
struct EnhancedChatView: View {
    
    // MARK: - Properties
    
    @Binding var isPresented: Bool
    @State private var chatViewModel = EnhancedChatViewModel()
    @State private var showingMemoryDetails = false
    @State private var contextSources: [ContextSource] = []
    
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isInputFocused: Bool
    
    private let logger = Logger(subsystem: "com.chaehoshin.Gemi", category: "EnhancedChatView")
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            
            if isPresented {
                chatPanel
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .background(backdropView)
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                isInputFocused = true
                Task {
                    await chatViewModel.initializeChat()
                }
            }
        }
    }
    
    // MARK: - Chat Panel
    
    private var chatPanel: some View {
        VStack(spacing: 0) {
            // Header with memory indicator
            chatHeader
            
            Divider()
                .opacity(0.1)
            
            // Active context indicator
            if !chatViewModel.activeContextSources.isEmpty {
                activeContextBar
            }
            
            // Messages
            messagesView
            
            // Input area
            EnhancedChatInputView(
                text: $chatViewModel.currentInput,
                isGenerating: chatViewModel.isGenerating,
                onSend: { Task { await chatViewModel.sendMessage() } },
                onCancel: { chatViewModel.cancelGeneration() }
            )
            .focused($isInputFocused)
        }
        .frame(width: 480)
        .frame(maxHeight: .infinity)
        .background(panelBackground)
        .overlay(panelBorder)
        .padding(24)
        .shadow(color: .black.opacity(0.15), radius: 30, x: -10, y: 0)
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack(spacing: 16) {
            // Gemi avatar with status
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primary,
                                DesignSystem.Colors.primary.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                    )
                
                // Status indicator
                Circle()
                    .fill(chatViewModel.isConnected ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Gemi")
                    .font(.system(size: 18, weight: .semibold))
                
                HStack(spacing: 4) {
                    Image(systemName: "brain")
                        .font(.system(size: 11))
                    
                    Text("\(chatViewModel.totalMemories) memories • \(chatViewModel.relevantMemories) relevant")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Memory details button
            Button {
                withAnimation(DesignSystem.Animation.standard) {
                    showingMemoryDetails.toggle()
                }
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Close button
            Button {
                withAnimation(DesignSystem.Animation.standard) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Active Context Bar
    
    private var activeContextBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chatViewModel.activeContextSources) { source in
                    ContextSourceChip(source: source)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(Color.primary.opacity(0.02))
    }
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(chatViewModel.messages) { message in
                        EnhancedMessageBubble(
                            message: message,
                            onContextTap: { context in
                                showContextDetails(context)
                            }
                        )
                        .id(message.id)
                    }
                    
                    if chatViewModel.isGenerating {
                        StreamingMessageBubble(
                            content: chatViewModel.streamingResponse,
                            contextSources: chatViewModel.currentContextSources
                        )
                        .id("streaming")
                    }
                }
                .padding(20)
                .padding(.bottom, 80)
            }
            .onChange(of: chatViewModel.messages.count) { _, _ in
                withAnimation {
                    if let lastMessage = chatViewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatViewModel.streamingResponse) { _, _ in
                withAnimation {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Backdrop
    
    private var backdropView: some View {
        Group {
            if isPresented {
                Color.black
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(DesignSystem.Animation.standard) {
                            isPresented = false
                        }
                    }
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Styling
    
    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.regularMaterial)
    }
    
    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
    }
    
    // MARK: - Methods
    
    private func showContextDetails(_ context: ContextSource) {
        // Implementation for showing context details
    }
}

// MARK: - Enhanced Chat View Model

@Observable
@MainActor
final class EnhancedChatViewModel {
    
    // MARK: - Properties
    
    var messages: [EnhancedChatMessage] = []
    var currentInput = ""
    var isGenerating = false
    var streamingResponse = ""
    var isConnected = true
    
    // Memory stats
    var totalMemories = 0
    var relevantMemories = 0
    
    // Context tracking
    var activeContextSources: [ContextSource] = []
    var currentContextSources: [ContextSource] = []
    
    // Services
    private let ollamaService = OllamaService.shared
    private let ragService = JournalRAGService.shared
    private let memoryStore = MemoryStore.shared
    private let conversationStore = ConversationStore.shared
    private let modelManager = GemiModelManager()
    
    private let logger = Logger(subsystem: "com.chaehoshin.Gemi", category: "EnhancedChatViewModel")
    private var streamTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    func initializeChat() async {
        // Load memory stats
        await loadMemoryStats()
        
        // Check model status
        await checkModelStatus()
        
        // Load recent conversation
        await loadRecentConversation()
        
        // Add welcome if no messages
        if messages.isEmpty {
            messages.append(EnhancedChatMessage(
                content: "Hello! I'm Gemi, your personal diary companion. I remember our past conversations and your journal entries. How are you feeling today?",
                isUser: false,
                contextSources: []
            ))
        }
    }
    
    // MARK: - Message Sending
    
    @MainActor
    func sendMessage() async {
        let userMessage = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }
        
        // Add user message
        messages.append(EnhancedChatMessage(
            content: userMessage,
            isUser: true,
            contextSources: []
        ))
        currentInput = ""
        
        // Cancel any existing stream
        streamTask?.cancel()
        
        // Start generating
        isGenerating = true
        streamingResponse = ""
        currentContextSources = []
        
        // Build context
        let context = await buildCompleteContext(for: userMessage)
        activeContextSources = context.sources
        
        // Stream response
        streamTask = Task {
            do {
                var fullResponse = ""
                
                for try await chunk in ollamaService.generateChatStream(
                    prompt: context.prompt,
                    model: modelManager.activeModelName
                ) {
                    guard !Task.isCancelled else { break }
                    
                    await MainActor.run {
                        streamingResponse += chunk
                        fullResponse += chunk
                    }
                }
                
                // Add complete message
                await MainActor.run {
                    messages.append(EnhancedChatMessage(
                        content: fullResponse,
                        isUser: false,
                        contextSources: context.sources
                    ))
                    
                    // Extract and store new memories
                    Task {
                        await self.extractMemories(from: userMessage, response: fullResponse)
                    }
                }
                
            } catch {
                await MainActor.run {
                    messages.append(EnhancedChatMessage(
                        content: "I'm sorry, I encountered an error: \(error.localizedDescription)",
                        isUser: false,
                        contextSources: []
                    ))
                }
            }
            
            await MainActor.run {
                isGenerating = false
                streamingResponse = ""
                currentContextSources = []
            }
        }
    }
    
    // MARK: - Context Building
    
    private func buildCompleteContext(for userMessage: String) async -> (prompt: String, sources: [ContextSource]) {
        var contextParts: [String] = []
        var sources: [ContextSource] = []
        
        // 1. Get recent conversation history
        let conversationHistory = await getRecentConversation(limit: 5)
        if !conversationHistory.isEmpty {
            contextParts.append("Recent conversation:\n\(conversationHistory)")
            sources.append(ContextSource(
                type: .conversation,
                title: "Recent chat",
                preview: "Last \(min(5, messages.count)) messages"
            ))
        }
        
        // 2. Search relevant journal entries
        do {
            let journalContext = try await ragService.getRelevantContext(
                for: userMessage,
                limit: 3
            )
            if !journalContext.isEmpty {
                contextParts.append(journalContext)
                sources.append(ContextSource(
                    type: .journal,
                    title: "Journal entries",
                    preview: "3 relevant entries found"
                ))
            }
        } catch {
            logger.error("Failed to get journal context: \(error)")
        }
        
        // 3. Search relevant memories
        do {
            let memories = try await memoryStore.searchMemories(
                query: userMessage,
                limit: 5
            )
            if !memories.isEmpty {
                let memoryContext = formatMemories(memories)
                contextParts.append("Relevant memories:\n\(memoryContext)")
                sources.append(ContextSource(
                    type: .memory,
                    title: "Memories",
                    preview: "\(memories.count) memories found"
                ))
                
                relevantMemories = memories.count
            }
        } catch {
            logger.error("Failed to search memories: \(error)")
        }
        
        // 4. Check for special queries
        let specialContext = await handleSpecialQueries(userMessage)
        if let special = specialContext {
            contextParts.append(special.context)
            sources.append(special.source)
        }
        
        // Build final prompt
        let fullContext = contextParts.joined(separator: "\n\n---\n\n")
        let prompt = """
        \(fullContext)
        
        Current message: \(userMessage)
        
        Please respond naturally and personally, referencing the context when relevant.
        """
        
        return (prompt, sources)
    }
    
    // MARK: - Special Query Handling
    
    private func handleSpecialQueries(_ message: String) async -> (context: String, source: ContextSource)? {
        let lowercased = message.lowercased()
        
        if lowercased.contains("my week") || lowercased.contains("this week") {
            // Summarize recent week
            let weekSummary = await summarizeRecentWeek()
            return (
                weekSummary,
                ContextSource(type: .analysis, title: "Week summary", preview: "Last 7 days")
            )
        }
        
        if lowercased.contains("how have i been") || lowercased.contains("feeling") {
            // Emotional analysis
            let emotionalAnalysis = await analyzeRecentEmotions()
            return (
                emotionalAnalysis,
                ContextSource(type: .analysis, title: "Emotional trends", preview: "Recent mood patterns")
            )
        }
        
        if lowercased.contains("what have we discussed") || lowercased.contains("past conversations") {
            // Conversation summary
            let conversationSummary = await summarizePastConversations()
            return (
                conversationSummary,
                ContextSource(type: .conversation, title: "Conversation history", preview: "Key topics")
            )
        }
        
        return nil
    }
    
    // MARK: - Memory Extraction
    
    private func extractMemories(from userMessage: String, response: String) async {
        // Extract important facts from the conversation
        let combinedText = "User: \(userMessage)\n\nGemi: \(response)"
        
        do {
            // Use Ollama to extract key facts
            let extractionPrompt = """
            Extract important personal facts, preferences, or memories from this conversation.
            Format each fact on a new line, starting with a dash.
            Only include significant information worth remembering.
            
            Conversation:
            \(combinedText)
            """
            
            let facts = try await ollamaService.generateChat(
                prompt: extractionPrompt,
                model: modelManager.activeModelName
            )
            
            // Parse and store facts
            let factLines = facts.components(separatedBy: "\n")
                .filter { $0.trimmingCharacters(in: .whitespaces).starts(with: "-") }
                .map { $0.trimmingCharacters(in: .whitespaces).dropFirst(1).trimmingCharacters(in: .whitespaces) }
            
            for fact in factLines where !fact.isEmpty {
                let memory = Memory(
                    content: String(fact),
                    embedding: nil,
                    sourceEntryId: nil,
                    importance: 0.7,
                    tags: ["conversation", "fact"],
                    isPinned: false,
                    memoryType: .conversationFact
                )
                
                try await DatabaseManager.shared().saveMemory(memory)
                
                // Show memory indicator
                await MainActor.run {
                    self.showMemoryStored(fact: String(fact))
                }
            }
        } catch {
            logger.error("Failed to extract memories: \(error)")
        }
    }
    
    // MARK: - UI Updates
    
    @MainActor
    private func showMemoryStored(fact: String) {
        // This would show a temporary notification
        logger.info("Stored memory: \(fact)")
    }
    
    // MARK: - Helper Methods
    
    private func loadMemoryStats() async {
        do {
            totalMemories = try await DatabaseManager.shared().getMemoryCount()
        } catch {
            logger.error("Failed to load memory stats: \(error)")
        }
    }
    
    private func checkModelStatus() async {
        if case .notCreated = modelManager.modelStatus {
            do {
                try await modelManager.updateGemiModel()
            } catch {
                logger.error("Failed to create custom model: \(error)")
            }
        }
    }
    
    private func loadRecentConversation() async {
        do {
            let recentMessages = try await conversationStore.getRecentMessages(limit: 10)
            messages = recentMessages.map { message in
                EnhancedChatMessage(
                    content: message.content,
                    isUser: message.role == "user",
                    contextSources: []
                )
            }
        } catch {
            logger.error("Failed to load recent conversation: \(error)")
        }
    }
    
    private func getRecentConversation(limit: Int) async -> String {
        let recentMessages = Array(messages.suffix(limit * 2)) // Get last N exchanges
        return recentMessages.map { msg in
            "\(msg.isUser ? "User" : "Gemi"): \(msg.content)"
        }.joined(separator: "\n")
    }
    
    private func formatMemories(_ memories: [Memory]) -> String {
        memories.map { memory in
            "- \(memory.content) (importance: \(String(format: "%.1f", memory.importance)))"
        }.joined(separator: "\n")
    }
    
    private func summarizeRecentWeek() async -> String {
        // Implementation for week summary
        "Summary of your week based on journal entries..."
    }
    
    private func analyzeRecentEmotions() async -> String {
        // Implementation for emotional analysis
        "Analysis of your recent emotional patterns..."
    }
    
    private func summarizePastConversations() async -> String {
        // Implementation for conversation summary
        "Summary of our past conversations..."
    }
    
    func cancelGeneration() {
        streamTask?.cancel()
        isGenerating = false
        streamingResponse = ""
    }
}

// MARK: - Enhanced Chat Message

struct EnhancedChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
    let contextSources: [ContextSource]
    let isError: Bool = false
}

// MARK: - Context Source

struct ContextSource: Identifiable {
    let id = UUID()
    let type: ContextType
    let title: String
    let preview: String
    
    enum ContextType {
        case journal
        case memory
        case conversation
        case analysis
        
        var icon: String {
            switch self {
            case .journal: return "book.closed"
            case .memory: return "brain"
            case .conversation: return "bubble.left.and.bubble.right"
            case .analysis: return "chart.line.uptrend.xyaxis"
            }
        }
        
        var color: Color {
            switch self {
            case .journal: return .blue
            case .memory: return .purple
            case .conversation: return .green
            case .analysis: return .orange
            }
        }
    }
}

// MARK: - UI Components

struct EnhancedMessageBubble: View {
    let message: EnhancedChatMessage
    let onContextTap: (ContextSource) -> Void
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            // Context indicators
            if !message.contextSources.isEmpty && !message.isUser {
                HStack(spacing: 6) {
                    ForEach(message.contextSources) { source in
                        ContextIndicator(source: source)
                            .onTapGesture {
                                onContextTap(source)
                            }
                    }
                }
            }
            
            // Message bubble
            HStack {
                if message.isUser { Spacer() }
                
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(message.isUser ? 
                                AnyShapeStyle(LinearGradient(
                                    colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )) : 
                                AnyShapeStyle(Color.primary.opacity(0.06))
                            )
                    )
                    .contextMenu {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        }
                    }
                
                if !message.isUser { Spacer() }
            }
            .frame(maxWidth: 320, alignment: message.isUser ? .trailing : .leading)
        }
    }
}

struct StreamingMessageBubble: View {
    let content: String
    let contextSources: [ContextSource]
    @State private var cursorVisible = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Context indicators
            if !contextSources.isEmpty {
                HStack(spacing: 6) {
                    ForEach(contextSources) { source in
                        ContextIndicator(source: source)
                    }
                }
            }
            
            // Message with cursor
            HStack {
                Text(content + (cursorVisible ? "▊" : " "))
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                
                Spacer()
            }
            .frame(maxWidth: 320, alignment: .leading)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                DispatchQueue.main.async {
                    cursorVisible.toggle()
                }
            }
        }
    }
}

struct ContextIndicator: View {
    let source: ContextSource
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source.type.icon)
                .font(.system(size: 10, weight: .medium))
            
            Text(source.title)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(source.type.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(source.type.color.opacity(0.1))
        )
    }
}

struct ContextSourceChip: View {
    let source: ContextSource
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: source.type.icon)
                    .font(.system(size: 12))
                
                Text(source.title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(source.type.color)
            
            Text(source.preview)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(source.type.color.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

struct EnhancedChatInputView: View {
    @Binding var text: String
    let isGenerating: Bool
    let onSend: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var textHeight: CGFloat = 40
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Text input
            ResizableTextEditor(
                text: $text,
                height: $textHeight,
                isFocused: $isFocused
            )
            .frame(height: min(textHeight, 120))
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(0.05))
            )
            
            // Action button
            Button {
                if isGenerating {
                    onCancel()
                } else {
                    onSend()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(text.isEmpty && !isGenerating)
        }
        .padding(16)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider().opacity(0.1)
                }
        )
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isPresented = true
    
    return ZStack {
        // Background
        Rectangle()
            .fill(Color(red: 0.96, green: 0.95, blue: 0.94))
        
        EnhancedChatView(isPresented: $isPresented)
    }
    .frame(width: 1200, height: 800)
}