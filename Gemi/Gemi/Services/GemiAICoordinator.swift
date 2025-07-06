import Foundation
import os.log

/// Coordinates all AI operations including context building, memory management, and chat orchestration
@MainActor
final class GemiAICoordinator: ObservableObject {
    static let shared = GemiAICoordinator()
    
    @Published var isProcessing = false
    @Published var currentContext: String?
    @Published var lastError: Error?
    
    private let logger = Logger(subsystem: "com.gemi", category: "GemiAICoordinator")
    private let ollamaService = OllamaService.shared
    private let memoryManager = MemoryManager.shared
    private let databaseManager = DatabaseManager.shared
    
    private init() {}
    
    /// Build context for a message with RAG (Retrieval-Augmented Generation)
    func buildContextForMessage(_ message: String, includeMemories: Bool = true) async throws -> [ChatMessage] {
        logger.info("Building context for message")
        isProcessing = true
        defer { isProcessing = false }
        
        var messages: [ChatMessage] = []
        
        // Build system context
        let systemPrompt = await buildSystemPrompt(includeMemories: includeMemories)
        messages.append(ChatMessage(role: .system, content: systemPrompt))
        
        // Add relevant journal context if available
        if includeMemories {
            if let journalContext = await findRelevantJournalEntries(for: message) {
                messages.append(ChatMessage(role: .system, content: journalContext))
            }
        }
        
        // Add the user message
        messages.append(ChatMessage(role: .user, content: message))
        
        currentContext = systemPrompt
        return messages
    }
    
    /// Send a message with full context and streaming response
    func sendMessage(_ message: String, memories: [String] = []) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Build full context
                    var contextMessages = try await buildContextForMessage(message)
                    
                    // Add memories as a system message if available
                    if !memories.isEmpty {
                        let memoriesContext = "Based on your journal entries, here's what I know about you:\n\n" + memories.joined(separator: "\n")
                        let systemMessage = ChatMessage(role: .system, content: memoriesContext)
                        contextMessages.insert(systemMessage, at: 0)
                    }
                    
                    // Stream the response
                    for try await response in await ollamaService.chat(messages: contextMessages) {
                        continuation.yield(response)
                        
                        if response.done {
                            // Save the conversation
                            await saveConversation(userMessage: message, response: response)
                            break
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    self.lastError = error
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Process a journal entry for memory extraction
    func processJournalEntry(_ entry: JournalEntry) async {
        logger.info("Processing journal entry for memory extraction")
        
        // Use MemoryManager to process entries
        await memoryManager.processEntries([entry])
        
        logger.info("Processed journal entry for memory extraction")
    }
    
    // MARK: - Private Methods
    
    private func buildSystemPrompt(includeMemories: Bool) async -> String {
        var prompt = """
        You are Gemi, a warm and empathetic AI diary companion. You're having a conversation with your friend who keeps a journal.
        
        Your personality:
        - Warm, supportive, and encouraging
        - Good listener who remembers past conversations
        - Offers thoughtful reflections without being preachy
        - Asks clarifying questions when appropriate
        - Celebrates wins and provides comfort during challenges
        
        """
        
        if includeMemories {
            // Get relevant memories
            let recentMemories = memoryManager.memories.prefix(10)
            if !recentMemories.isEmpty {
                prompt += "\nThings you remember about your friend:\n"
                for memory in recentMemories {
                    prompt += "- \(memory.content)\n"
                }
            }
        }
        
        prompt += "\nRespond naturally and conversationally, as a caring friend would."
        
        return prompt
    }
    
    private func findRelevantJournalEntries(for query: String) async -> String? {
        do {
            // Search for relevant entries
            let entries = try await databaseManager.searchEntries(query: query)
            
            guard !entries.isEmpty else { return nil }
            
            var context = "Relevant context from your friend's journal:\n\n"
            
            // Include up to 3 most relevant entries
            for (index, entry) in entries.prefix(3).enumerated() {
                let preview = String(entry.content.prefix(200))
                let date = entry.createdAt.formatted(date: .abbreviated, time: .omitted)
                context += "[\(date)] \(preview)...\n"
                
                if index < entries.count - 1 {
                    context += "\n"
                }
            }
            
            return context
        } catch {
            logger.error("Failed to find relevant journal entries: \(error)")
            return nil
        }
    }
    
    private func saveConversation(userMessage: String, response: ChatResponse) async {
        // TODO: Implement conversation persistence
        // This would save the conversation to the database for future reference
        logger.info("Conversation saved (not implemented)")
    }
    
    /// Build context with graceful degradation
    func buildRobustContext(for message: String) async throws -> String {
        do {
            // Try full context building
            let messages = try await buildContextForMessage(message)
            return messages.map { $0.content }.joined(separator: "\n\n")
        } catch {
            logger.warning("Full context building failed, using fallback: \(error)")
            
            // Fallback: Simple context
            return """
            You are Gemi, a warm and empathetic AI diary companion.
            Please respond helpfully to: \(message)
            """
        }
    }
}