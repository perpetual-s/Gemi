import Foundation
import SwiftUI

/// Enhanced chat view model with clean architecture and proper state management
@MainActor
final class EnhancedChatViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var messages: [ChatHistoryMessage] = []
    @Published var isStreaming = false
    @Published var isTyping = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var suggestedPrompts: [String] = []
    @Published var error: Error?
    @Published var isMultimodalSupported = false
    
    // MARK: - Private Properties
    
    private let aiService = AIService.shared
    private let memoryManager = MemoryManager.shared
    private let aiCoordinator = GemiAICoordinator.shared
    private var connectionMonitorTask: Task<Void, Never>?
    private var currentStreamingTask: Task<Void, Never>?
    private let messagesPersistenceKey = "com.gemi.chat.messages"
    private let maxStoredMessages = 100 // Limit stored messages to prevent excessive storage
    private var lastConnectionCheck = Date()
    private let connectionCheckInterval: TimeInterval = 60 // Check every 60 seconds
    private var lastKnownConnectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Types
    
    enum ConnectionStatus: Equatable {
        case connected
        case connecting
        case disconnected
    }
    
    // MARK: - Initialization
    
    init() {
        setupInitialPrompts()
    }
    
    deinit {
        connectionMonitorTask?.cancel()
        currentStreamingTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring the connection to AI server
    func startConnectionMonitoring() {
        // Cancel any existing monitoring
        connectionMonitorTask?.cancel()
        
        // Start new monitoring
        connectionMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                // Check immediately if disconnected
                if self?.lastKnownConnectionStatus == .disconnected {
                    self?.checkAIConnection()
                } else if let self = self, Date().timeIntervalSince(self.lastConnectionCheck) >= self.connectionCheckInterval {
                    // Only check periodically if connected
                    self.checkAIConnectionSilently()
                }
                
                // Wait 30 seconds between checks to reduce frequency
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        
        // Check immediately
        Task {
            checkAIConnection()
        }
    }
    
    /// Check the connection to AI server silently (without updating UI unless status changes)
    private func checkAIConnectionSilently() {
        Task {
            lastConnectionCheck = Date()
            
            do {
                let isHealthy = try await aiService.checkHealth()
                let newStatus: ConnectionStatus = isHealthy ? .connected : .disconnected
                
                // Only update if status actually changed
                if lastKnownConnectionStatus != newStatus {
                    lastKnownConnectionStatus = newStatus
                    connectionStatus = newStatus
                }
            } catch {
                // Only update if not already disconnected
                if lastKnownConnectionStatus != .disconnected {
                    lastKnownConnectionStatus = .disconnected
                    connectionStatus = .disconnected
                }
            }
        }
    }
    
    /// Check the connection to AI server
    func checkAIConnection() {
        Task {
            guard lastKnownConnectionStatus != .connecting else { return }
            
            // Only update to connecting if we're currently disconnected
            // This prevents unnecessary UI updates
            if lastKnownConnectionStatus == .disconnected {
                lastKnownConnectionStatus = .connecting
                connectionStatus = .connecting
            }
            
            do {
                let isHealthy = try await aiService.checkHealth()
                let newStatus: ConnectionStatus = isHealthy ? .connected : .disconnected
                
                // Only update if status actually changed
                if lastKnownConnectionStatus != newStatus {
                    lastKnownConnectionStatus = newStatus
                    connectionStatus = newStatus
                }
                
                if !isHealthy {
                    print("AI server health check failed")
                } else {
                    // Check if current model supports multimodal
                    let isMultimodal = await aiService.isMultimodalModel()
                    isMultimodalSupported = isMultimodal
                    
                    if !isMultimodal {
                        print("Note: Current model does not support multimodal input. Images will be ignored.")
                    }
                }
            } catch {
                // Only update if not already disconnected
                if lastKnownConnectionStatus != .disconnected {
                    lastKnownConnectionStatus = .disconnected
                    connectionStatus = .disconnected
                }
                print("AI server connection error: \(error)")
                
                // Don't show error alerts for connection checks
                // The UI will show the connection status
            }
        }
    }
    
    /// Send a message to the AI
    func sendMessage(_ content: String, images: [String]? = nil) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard connectionStatus == .connected else {
            error = AIServiceError.serviceUnavailable("Please wait for connection to AI server")
            return
        }
        
        // Cancel any existing streaming
        currentStreamingTask?.cancel()
        
        // Clear error
        error = nil
        
        // Add user message with images if provided
        let userMessage = ChatHistoryMessage(role: .user, content: content, images: images)
        messages.append(userMessage)
        
        // Start typing indicator
        isTyping = true
        
        // Small delay for natural feel
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        isTyping = false
        isStreaming = true
        
        // Create placeholder for assistant message
        let assistantMessage = ChatHistoryMessage(role: .assistant, content: "")
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1
        
        // Build context with system prompts and memories
        var aiMessages: [ChatMessage] = []
        
        // Add system prompt with Gemi's personality and context
        let systemPrompt = buildSystemPrompt()
        aiMessages.append(ChatMessage(role: .system, content: systemPrompt))
        
        // Add relevant memories if available
        let relevantMemories = memoryManager.searchMemories(for: content)
        if !relevantMemories.isEmpty {
            let memoryContext = "Based on your journal entries, here's what I know about you:\n\n" + relevantMemories.map { "- " + $0.content }.joined(separator: "\n")
            aiMessages.append(ChatMessage(role: .system, content: memoryContext))
        }
        
        // Convert existing messages to AI format
        let existingMessages = messages.dropLast().map { msg in
            ChatMessage(
                role: ChatMessage.Role(rawValue: msg.role.rawValue) ?? .user,
                content: msg.content,
                images: msg.images
            )
        }
        aiMessages.append(contentsOf: existingMessages)
        
        // Stream the response
        currentStreamingTask = Task { [weak self] in
            guard let self = self else { return }
            var accumulatedContent = ""
            
            do {
                for try await response in await self.aiService.chat(messages: aiMessages) {
                    if Task.isCancelled { break }
                    
                    if let message = response.message {
                        accumulatedContent += message.content
                        
                        // Update the message
                        await MainActor.run { [weak self] in
                            guard let self = self,
                                  self.messages.count > assistantIndex else { return }
                            
                            // Trim whitespace and newlines more aggressively to prevent empty space
                            var trimmedContent = accumulatedContent.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Also remove any double newlines that might cause excessive spacing
                            while trimmedContent.contains("\n\n\n") {
                                trimmedContent = trimmedContent.replacingOccurrences(of: "\n\n\n", with: "\n\n")
                            }
                            
                            self.messages[assistantIndex] = ChatHistoryMessage(
                                role: .assistant,
                                content: trimmedContent
                            )
                        }
                    }
                    
                    if response.done {
                        break
                    }
                }
                
                // Update prompts based on conversation
                await MainActor.run { [weak self] in
                    self?.updateSuggestedPrompts()
                }
                
                // Save messages after ensuring all updates are complete
                await MainActor.run { [weak self] in
                    _ = Task { @MainActor [weak self] in
                        // Small delay to ensure message content is fully updated
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                        self?.saveMessages()
                    }
                }
                
            } catch {
                // Handle errors
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    
                    // Remove empty assistant message if no content was received
                    if accumulatedContent.isEmpty && self.messages.count > assistantIndex {
                        self.messages.remove(at: assistantIndex)
                    }
                    
                    // Set appropriate error
                    if error is AIServiceError {
                        self.error = error
                    } else {
                        self.error = AIServiceError.connectionFailed(error.localizedDescription)
                    }
                }
            }
            
            await MainActor.run { [weak self] in
                self?.isStreaming = false
            }
        }
    }
    
    /// Start a new chat
    func startNewChat() {
        // Cancel any ongoing streaming
        currentStreamingTask?.cancel()
        
        // Clear state
        messages = []
        isStreaming = false
        isTyping = false
        error = nil
        
        // Reset prompts
        setupInitialPrompts()
        
        // Clear saved messages
        UserDefaults.standard.removeObject(forKey: messagesPersistenceKey)
    }
    
    // MARK: - System Prompt Building
    
    private func buildSystemPrompt() -> String {
        return """
        You are Gemi, a thoughtful and empathetic AI journal companion. Your role is to help users with their personal reflections and journal entries.
        
        Context about the app:
        - This is a private, offline journal app where users write personal diary entries
        - Users can write entries, reflect on their day, and have conversations with you
        - When users ask to "write an entry", they mean a journal/diary entry about their day or thoughts
        - All conversations happen within the context of personal journaling and self-reflection
        
        Your personality:
        - Warm, supportive, and encouraging
        - Good listener who remembers past conversations
        - Offers thoughtful reflections without being preachy
        - Helps users explore their thoughts and feelings through journaling
        - When asked to help write an entry, suggest prompts about their day, feelings, or experiences
        
        IMPORTANT: DO NOT use markdown formatting like **bold** or *italic* in your responses. Write in plain text only.
        
        Respond naturally and conversationally, as a caring friend would.
        """
    }
    
    // MARK: - Private Methods
    
    private func setupInitialPrompts() {
        suggestedPrompts = [
            "How are you feeling today?",
            "What's on your mind?",
            "Help me reflect on my day"
        ]
    }
    
    private func updateSuggestedPrompts() {
        // Analyze the last message to suggest contextual prompts
        guard let lastUserMessage = messages.reversed().first(where: { $0.role == .user })?.content else {
            setupInitialPrompts()
            return
        }
        
        let lowercased = lastUserMessage.lowercased()
        
        if lowercased.contains("feeling") || lowercased.contains("emotion") || lowercased.contains("mood") {
            suggestedPrompts = [
                "What triggered these feelings?",
                "How can I process this emotion?",
                "What would help me feel better?"
            ]
        } else if lowercased.contains("goal") || lowercased.contains("plan") || lowercased.contains("future") {
            suggestedPrompts = [
                "What's the first step I should take?",
                "What obstacles might I face?",
                "How will I measure success?"
            ]
        } else if lowercased.contains("problem") || lowercased.contains("issue") || lowercased.contains("challenge") {
            suggestedPrompts = [
                "What solutions have I tried?",
                "Who could help me with this?",
                "What's the worst that could happen?"
            ]
        } else if lowercased.contains("grateful") || lowercased.contains("thankful") || lowercased.contains("appreciate") {
            suggestedPrompts = [
                "What else am I grateful for?",
                "How can I express this gratitude?",
                "What made this possible?"
            ]
        } else {
            suggestedPrompts = [
                "Tell me more about that",
                "How does that make you feel?",
                "What else is on your mind?"
            ]
        }
    }
    
    // MARK: - Message Persistence
    
    /// Save messages to UserDefaults
    func saveMessages() {
        // Only save recent messages to avoid excessive storage
        let messagesToSave = Array(messages.suffix(maxStoredMessages))
        
        // Convert to simple dictionary format for storage
        let messageData = messagesToSave.map { message in
            [
                "id": message.id.uuidString,
                "role": message.role.rawValue,
                "content": message.content,
                "timestamp": message.timestamp.timeIntervalSince1970
            ]
        }
        
        UserDefaults.standard.set(messageData, forKey: messagesPersistenceKey)
    }
    
    /// Load messages from UserDefaults
    func loadMessages() {
        guard let messageData = UserDefaults.standard.array(forKey: messagesPersistenceKey) as? [[String: Any]] else {
            return
        }
        
        messages = messageData.compactMap { dict in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let roleString = dict["role"] as? String,
                  let role = ChatHistoryMessage.MessageRole(rawValue: roleString),
                  let content = dict["content"] as? String,
                  let timestamp = dict["timestamp"] as? TimeInterval else {
                return nil
            }
            
            return ChatHistoryMessage(
                id: id,
                role: role,
                content: content,
                timestamp: Date(timeIntervalSince1970: timestamp)
            )
        }
        
        // Update suggested prompts based on loaded conversation
        if !messages.isEmpty {
            updateSuggestedPrompts()
        }
    }
    
    // MARK: - Error Handling
    
    /// Get a user-friendly error message
    func errorMessage(for error: Error) -> String {
        if let aiError = error as? AIServiceError {
            return aiError.localizedDescription
        }
        return "An unexpected error occurred. Please try again."
    }
    
    /// Get recovery suggestion for an error
    func recoverySuggestion(for error: Error) -> String? {
        if let aiError = error as? AIServiceError {
            return aiError.recoverySuggestion
        }
        return nil
    }
}