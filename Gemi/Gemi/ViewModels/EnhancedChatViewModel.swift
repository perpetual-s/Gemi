import Foundation
import SwiftUI

/// Enhanced chat view model with streaming, memory integration, and connection management
@MainActor
final class EnhancedChatViewModel: ObservableObject {
    @Published var messages: [ChatHistoryMessage] = []
    @Published var currentConversation: ChatConversation?
    @Published var conversations: [ChatConversation] = []
    @Published var isStreaming = false
    @Published var isTyping = false
    @Published var error: Error?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var showingContextPanel = false
    @Published var activeMemories: [Memory] = []
    @Published var suggestedPrompts: [String] = []
    
    private let coordinator = GemiAICoordinator.shared
    private let memoryManager = MemoryManager.shared
    private let ollamaService = OllamaService.shared
    private let processManager = OllamaProcessManager.shared
    private let databaseManager = DatabaseManager.shared
    
    private var streamingMessage = ""
    private var connectionCheckTask: Task<Void, Never>?
    
    enum ConnectionStatus {
        case connected
        case connecting
        case disconnected
    }
    
    init() {
        setupConnectionMonitoring()
        loadConversations()
        generateSuggestedPrompts()
    }
    
    deinit {
        connectionCheckTask?.cancel()
    }
    
    // MARK: - Connection Management
    
    private func setupConnectionMonitoring() {
        checkOllamaConnection()
        
        // Check connection every 5 seconds
        connectionCheckTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                if !Task.isCancelled {
                    await checkOllamaConnection()
                }
            }
        }
    }
    
    func checkOllamaConnection() {
        Task {
            connectionStatus = .connecting
            
            do {
                // Ensure Ollama is running
                try await processManager.ensureOllamaRunning()
                
                // Check if model is available
                let isHealthy = try await ollamaService.checkHealth()
                connectionStatus = isHealthy ? .connected : .disconnected
            } catch {
                connectionStatus = .disconnected
                print("Connection check failed: \(error)")
            }
        }
    }
    
    // MARK: - Message Handling
    
    func sendMessage(_ content: String, withMemories specificMemories: [Memory]? = nil) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard connectionStatus == .connected else {
            error = OllamaError.serviceUnavailable
            return
        }
        
        // Add user message
        let userMessage = ChatHistoryMessage(role: .user, content: content)
        messages.append(userMessage)
        
        // Show typing indicator
        isTyping = true
        
        // Simulate typing delay for natural feel
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isTyping = false
        isStreaming = true
        streamingMessage = ""
        error = nil
        
        do {
            // Get relevant memories
            let memories = specificMemories ?? memoryManager.getRelevantMemories(for: content)
            activeMemories = memories
            
            // Build context messages
            let _ = try await coordinator.buildContextForMessage(content, includeMemories: !memories.isEmpty)
            
            // Create assistant message placeholder
            let assistantMessage = ChatHistoryMessage(role: .assistant, content: "")
            messages.append(assistantMessage)
            let assistantIndex = messages.count - 1
            
            // Stream the response
            for try await response in coordinator.sendMessage(content, memories: memories.map { $0.content }) {
                if let message = response.message {
                    streamingMessage += message.content
                    
                    // Update the message with animation
                    withAnimation(.easeInOut(duration: 0.1)) {
                        messages[assistantIndex] = ChatHistoryMessage(
                            role: .assistant,
                            content: streamingMessage
                        )
                    }
                }
                
                if response.done {
                    break
                }
            }
            
            // Save conversation
            await saveCurrentConversation()
            
            // Generate new prompts based on conversation
            generateContextualPrompts()
            
        } catch {
            self.error = error
            // Remove the empty assistant message
            if messages.last?.content.isEmpty == true {
                messages.removeLast()
            }
        }
        
        isStreaming = false
    }
    
    // MARK: - Conversation Management
    
    func loadConversations() {
        // TODO: Load from database when persistence is implemented
        conversations = []
    }
    
    func createNewConversation(title: String? = nil) {
        let conversation = ChatConversation(
            title: title ?? "New Chat \(Date().formatted(date: .abbreviated, time: .shortened))"
        )
        currentConversation = conversation
        messages = []
        activeMemories = []
        generateSuggestedPrompts()
    }
    
    func loadConversation(_ conversation: ChatConversation) {
        currentConversation = conversation
        messages = conversation.messages
        activeMemories = []
    }
    
    private func saveCurrentConversation() async {
        guard let conversation = currentConversation else { return }
        
        conversation.messages = messages
        conversation.updatedAt = Date()
        
        // TODO: Persist to database
    }
    
    func deleteConversation(_ conversation: ChatConversation) {
        conversations.removeAll { $0.id == conversation.id }
        if currentConversation?.id == conversation.id {
            currentConversation = nil
            messages = []
        }
        
        // TODO: Delete from database
    }
    
    // MARK: - Prompts & Suggestions
    
    private func generateSuggestedPrompts() {
        // Get recent journal entries for context
        Task {
            do {
                let entries = try await databaseManager.loadEntries()
                let recentEntries = Array(entries.prefix(10))
                
                // Use the companion service to generate prompts
                let contextualPrompts = await CompanionModelService.shared.generateReflectionPrompts(basedOn: recentEntries)
                
                suggestedPrompts = contextualPrompts.isEmpty ? defaultPrompts : contextualPrompts
            } catch {
                suggestedPrompts = defaultPrompts
            }
        }
    }
    
    private func generateContextualPrompts() {
        // Generate follow-up prompts based on current conversation
        guard messages.count > 2 else { return }
        
        // This could be enhanced with AI-generated suggestions
        let lastUserMessage = messages.reversed().first { $0.role == .user }?.content ?? ""
        
        if lastUserMessage.lowercased().contains("feeling") || lastUserMessage.lowercased().contains("emotion") {
            suggestedPrompts = [
                "What physical sensations accompany these feelings?",
                "When did you first notice feeling this way?",
                "What would help you feel more grounded right now?"
            ]
        } else if lastUserMessage.lowercased().contains("goal") || lastUserMessage.lowercased().contains("plan") {
            suggestedPrompts = [
                "What's the first small step you could take?",
                "What might get in the way, and how can you prepare?",
                "How will you know when you've made progress?"
            ]
        } else {
            suggestedPrompts = [
                "Tell me more about that.",
                "How does that make you feel?",
                "What would you like to explore next?"
            ]
        }
    }
    
    private let defaultPrompts = [
        "How are you feeling today?",
        "What's on your mind?",
        "Help me reflect on my day"
    ]
    
    // MARK: - Memory Integration
    
    func getRelevantMemoriesForCurrentConversation() -> [Memory] {
        guard !messages.isEmpty else { return [] }
        
        let conversationText = messages.map { $0.content }.joined(separator: " ")
        return memoryManager.getRelevantMemories(for: conversationText, limit: 5)
    }
    
    // MARK: - Export & Sharing
    
    func exportConversation(format: ExportFormat) -> String {
        switch format {
        case .markdown:
            return exportAsMarkdown()
        case .plainText:
            return exportAsPlainText()
        case .json:
            return exportAsJSON()
        }
    }
    
    private func exportAsMarkdown() -> String {
        var markdown = "# Chat with Gemi\n\n"
        markdown += "*\(currentConversation?.createdAt.formatted() ?? Date().formatted())*\n\n"
        
        for message in messages {
            let role = message.role == .user ? "You" : "Gemi"
            markdown += "**\(role)**: \(message.content)\n\n"
        }
        
        return markdown
    }
    
    private func exportAsPlainText() -> String {
        var text = "Chat with Gemi\n"
        text += "\(currentConversation?.createdAt.formatted() ?? Date().formatted())\n\n"
        
        for message in messages {
            let role = message.role == .user ? "You" : "Gemi"
            text += "\(role): \(message.content)\n\n"
        }
        
        return text
    }
    
    private func exportAsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(messages) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    enum ExportFormat {
        case markdown
        case plainText
        case json
    }
}

// MARK: - Conversation Sidebar

struct ConversationSidebar: View {
    @ObservedObject var viewModel: EnhancedChatViewModel
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Conversations")
                    .font(Theme.Typography.headline)
                
                Spacer()
                
                Button {
                    viewModel.createNewConversation()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.Colors.secondaryText)
                
                TextField("Search conversations...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.smallCornerRadius)
            .padding(.horizontal)
            
            // Conversations list
            ScrollView {
                VStack(spacing: 4) {
                    if viewModel.conversations.isEmpty {
                        Text("No conversations yet")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                            .padding(.top, Theme.largeSpacing)
                    } else {
                        ForEach(filteredConversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: viewModel.currentConversation?.id == conversation.id
                            ) {
                                viewModel.loadConversation(conversation)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Theme.Colors.windowBackground)
    }
    
    private var filteredConversations: [ChatConversation] {
        if searchText.isEmpty {
            return viewModel.conversations
        }
        
        return viewModel.conversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(searchText) ||
            conversation.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

struct ConversationRow: View {
    let conversation: ChatConversation
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(Theme.Typography.body)
                    .lineLimit(1)
                
                if let lastMessage = conversation.messages.last {
                    Text(lastMessage.content)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .lineLimit(2)
                }
                
                Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            .padding(Theme.smallSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                    .fill(isSelected ? Theme.Colors.selectedBackground : (isHovered ? Theme.Colors.hoverBackground : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Context Panel

struct ContextPanel: View {
    @ObservedObject var viewModel: EnhancedChatViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Active Context")
                .font(Theme.Typography.headline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    if viewModel.activeMemories.isEmpty {
                        Text("No memories active for this conversation")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                            .padding()
                    } else {
                        ForEach(viewModel.activeMemories) { memory in
                            MemoryCard(memory: memory)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Theme.Colors.windowBackground)
    }
}

struct MemoryCard: View {
    let memory: Memory
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            HStack {
                Label(memory.category.rawValue, systemImage: categoryIcon)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.primaryAccent)
                
                Spacer()
                
                ImportanceIndicator(level: memory.importance)
            }
            
            Text(memory.content)
                .font(Theme.Typography.body)
                .lineLimit(3)
            
            Text("From \(memory.extractedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
        }
        .padding(Theme.spacing)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.smallCornerRadius)
    }
    
    private var categoryIcon: String {
        switch memory.category {
        case .personal: return "person"
        case .emotional: return "heart"
        case .goals: return "target"
        case .relationships: return "person.2"
        case .achievements: return "trophy"
        case .challenges: return "exclamationmark.triangle"
        case .preferences: return "slider.horizontal.3"
        case .routine: return "clock"
        }
    }
}

struct ImportanceIndicator: View {
    let level: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Circle()
                    .fill(index <= level ? Theme.Colors.primaryAccent : Theme.Colors.divider)
                    .frame(width: 6, height: 6)
            }
        }
    }
}