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
        
        // Use AI to extract meaningful memories
        do {
            let memories = try await extractMemoriesWithAI(from: entry)
            
            // Save memories to database
            for memoryData in memories {
                try? await databaseManager.saveMemory(memoryData)
            }
            
            // Refresh memory manager
            await memoryManager.loadMemories()
            
            logger.info("Successfully extracted \(memories.count) memories from entry")
        } catch {
            logger.error("Failed to extract memories: \(error)")
        }
    }
    
    /// Extract memories using Gemma3n AI
    private func extractMemoriesWithAI(from entry: JournalEntry) async throws -> [MemoryData] {
        // Skip very short entries
        guard entry.content.trimmingCharacters(in: .whitespacesAndNewlines).count > 10 else {
            logger.info("Entry too short for memory extraction")
            return []
        }
        
        let prompt = """
        Read this journal entry and extract 2-5 things worth remembering about the person who wrote it.
        These could be facts about them, their feelings, goals, relationships, or anything meaningful.
        
        Journal Entry:
        \(entry.content)
        
        Respond with a simple list of memories, one per line. Keep each memory concise and clear.
        For example:
        - Lives in California and wants to explore the area
        - Has a meeting on August 2nd
        - Feeling grateful today
        """
        
        let messages = [
            ChatMessage(role: .system, content: "You are an AI that extracts memorable information from journal entries. Be concise and focus on what's worth remembering."),
            ChatMessage(role: .user, content: prompt)
        ]
        
        var fullResponse = ""
        
        // Collect the full response
        for try await response in await ollamaService.chat(messages: messages) {
            fullResponse += response.message?.content ?? ""
            
            if response.done {
                break
            }
        }
        
        logger.info("AI Response: \(fullResponse)")
        
        // Check if AI is asking for the entry content (indicates it didn't receive it)
        if fullResponse.lowercased().contains("please provide") || 
           fullResponse.lowercased().contains("paste the text") ||
           fullResponse.lowercased().contains("i'm ready") {
            logger.warning("AI didn't receive journal content properly, using fallback extraction")
            return extractBasicMemory(from: entry)
        }
        
        // Parse the simple text response
        let memories = parseSimpleMemories(fullResponse, for: entry)
        
        // If no memories extracted, use basic extraction
        if memories.isEmpty {
            return extractBasicMemory(from: entry)
        }
        
        return memories
    }
    
    private func extractBasicMemory(from entry: JournalEntry) -> [MemoryData] {
        // Extract first meaningful sentence as a basic memory
        let content = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return [] }
        
        let memory = MemoryData(
            content: String(content.prefix(200)),
            sourceEntryID: entry.id
        )
        
        return [memory]
    }
    
    private func parseSimpleMemories(_ response: String, for entry: JournalEntry) -> [MemoryData] {
        // Split by newlines and look for lines that start with -, *, or are meaningful sentences
        let lines = response.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var memories: [MemoryData] = []
        
        for line in lines {
            // Remove common list markers
            let cleanedLine = line
                .replacingOccurrences(of: "^[-*•]\\s*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines or very short ones
            if cleanedLine.count < 10 {
                continue
            }
            
            // Create a simple memory
            memories.append(MemoryData(
                content: cleanedLine,
                sourceEntryID: entry.id
            ))
            
            // Limit to 5 memories per entry
            if memories.count >= 5 {
                break
            }
        }
        
        // If no memories found, extract a simple summary
        if memories.isEmpty && !entry.content.isEmpty {
            let summary = String(entry.content.prefix(150))
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !summary.isEmpty {
                memories.append(MemoryData(
                    content: summary,
                    sourceEntryID: entry.id
                ))
            }
        }
        
        return memories
    }
    
    // Removed - replaced by parseSimpleMemories
    
    // Removed categorization methods - using simple approach now
    
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
    
    /// Generate AI insights for a journal entry
    func generateInsights(for entry: JournalEntry) async throws -> (summary: String, keyPoints: [String], prompts: [String]) {
        logger.info("Generating AI insights for journal entry")
        
        let prompt = """
        Analyze this journal entry and provide thoughtful insights.
        
        Entry:
        Title: \(entry.displayTitle)
        Content: \(entry.content)
        Mood: \(entry.mood?.rawValue ?? "Not specified")
        Tags: \(entry.tags.joined(separator: ", "))
        
        Please provide:
        1. A brief 2-3 sentence summary that captures the essence of the entry
        2. 3-4 key points or themes present in the entry
        3. 2-3 thoughtful reflection prompts that encourage deeper self-exploration
        
        Format your response exactly as JSON:
        {
            "summary": "Your summary here",
            "keyPoints": ["Point 1", "Point 2", "Point 3"],
            "prompts": ["Prompt 1", "Prompt 2", "Prompt 3"]
        }
        """
        
        let messages = [
            ChatMessage(role: .system, content: "You are Gemi, an empathetic AI diary companion. Provide thoughtful, personalized insights that help with self-reflection and growth."),
            ChatMessage(role: .user, content: prompt)
        ]
        
        var fullResponse = ""
        
        // Collect the full response
        for try await response in await ollamaService.chat(messages: messages) {
            fullResponse += response.message?.content ?? ""
            
            if response.done {
                break
            }
        }
        
        // Parse JSON response
        guard let data = fullResponse.data(using: .utf8) else {
            throw OllamaError.invalidResponse("Invalid response format")
        }
        
        do {
            let decoder = JSONDecoder()
            let insights = try decoder.decode(InsightsResponse.self, from: data)
            return (insights.summary, insights.keyPoints, insights.prompts)
        } catch {
            // Fallback to basic parsing if JSON fails
            logger.warning("Failed to parse JSON response, using fallback parsing")
            return parseInsightsFromText(fullResponse)
        }
    }
    
    private func parseInsightsFromText(_ text: String) -> (summary: String, keyPoints: [String], prompts: [String]) {
        // Basic fallback parsing logic
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        let summary = lines.first ?? "This entry reflects personal thoughts and experiences."
        let keyPoints = Array(lines.prefix(4).dropFirst()).map { $0.trimmingCharacters(in: .whitespaces) }
        let prompts = [
            "What emotions stand out most in this entry?",
            "How might these experiences shape your future actions?",
            "What would you tell a friend in a similar situation?"
        ]
        
        return (summary, keyPoints.isEmpty ? ["Personal reflection captured", "Emotional awareness demonstrated", "Growth mindset evident"] : keyPoints, prompts)
    }
}

// MARK: - Response Models

private struct InsightsResponse: Codable {
    let summary: String
    let keyPoints: [String]
    let prompts: [String]
}

// Removed ExtractedMemory struct - no longer using JSON approach