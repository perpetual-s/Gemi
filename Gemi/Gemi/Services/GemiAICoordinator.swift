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
        let prompt = """
        Analyze this journal entry and extract 2-5 important memories.
        
        Journal Entry:
        Date: \(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
        Mood: \(entry.mood?.rawValue ?? "Not specified")
        Content: \(entry.content.prefix(1000))
        
        Extract memories about:
        - Personal facts or preferences
        - Emotions and feelings
        - Goals or plans
        - People mentioned
        - Events or experiences
        
        Respond with ONLY a JSON array, no other text:
        [{"content": "memory text", "category": "personal", "importance": 3}]
        
        Categories: personal, emotional, goals, relationships, achievements, challenges, preferences, routine
        Importance: 1-5 (5 is most important)
        """
        
        let messages = [
            ChatMessage(role: .system, content: "Extract memories from journal entries. Respond with JSON only."),
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
        
        // Try to extract JSON from the response
        let extractedMemories = extractJSONFromResponse(fullResponse, for: entry)
        
        if !extractedMemories.isEmpty {
            return extractedMemories
        }
        
        // Fallback to parsing the response text
        return parseMemoriesFromText(fullResponse, for: entry)
    }
    
    private func extractJSONFromResponse(_ response: String, for entry: JournalEntry) -> [MemoryData] {
        // Try to find JSON array in the response
        if let startIndex = response.firstIndex(of: "["),
           let endIndex = response.lastIndex(of: "]") {
            let jsonString = String(response[startIndex...endIndex])
            
            if let data = jsonString.data(using: .utf8) {
                do {
                    let decoder = JSONDecoder()
                    let extractedMemories = try decoder.decode([ExtractedMemory].self, from: data)
                    
                    return extractedMemories.compactMap { extracted in
                        // Validate and clean the extracted memory
                        guard !extracted.content.isEmpty else { return nil }
                        
                        let category = Memory.MemoryCategory.allCases.first { 
                            $0.rawValue.lowercased() == extracted.category.lowercased() 
                        } ?? .personal
                        
                        return MemoryData(
                            content: extracted.content,
                            sourceEntryID: entry.id,
                            category: category,
                            importance: min(max(extracted.importance, 1), 5)
                        )
                    }
                } catch {
                    logger.warning("JSON parsing failed: \(error)")
                }
            }
        }
        
        return []
    }
    
    private func parseMemoriesFromText(_ text: String, for entry: JournalEntry) -> [MemoryData] {
        var memories: [MemoryData] = []
        
        // Split by common delimiters and extract meaningful sentences
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 20 }
        
        for line in lines {
            // Skip lines that look like JSON syntax or instructions
            if line.contains("{") || line.contains("}") || line.contains("```") {
                continue
            }
            
            // Extract if it looks like a memory
            if line.contains("memory") || line.contains("remember") || 
               line.starts(with: "-") || line.starts(with: "*") || line.starts(with: "•") {
                
                let content = line
                    .replacingOccurrences(of: "^[-*•]\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if content.count > 15 {
                    let category = categorizeMemory(content)
                    let importance = determineImportance(content)
                    
                    memories.append(MemoryData(
                        content: content,
                        sourceEntryID: entry.id,
                        category: category,
                        importance: importance
                    ))
                }
            }
        }
        
        // If no memories found, extract key sentences from the entry itself
        if memories.isEmpty {
            logger.info("No memories found in AI response, using basic extraction")
            // Basic extraction when AI fails
            let summary = String(entry.content.prefix(200))
                .components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if !summary.isEmpty {
                memories.append(MemoryData(
                    content: summary,
                    sourceEntryID: entry.id,
                    category: .personal,
                    importance: 3
                ))
            }
        }
        
        return Array(memories.prefix(5))
    }
    
    private func categorizeMemory(_ content: String) -> Memory.MemoryCategory {
        let lowercased = content.lowercased()
        
        if lowercased.contains("feel") || lowercased.contains("emotion") || lowercased.contains("mood") {
            return .emotional
        } else if lowercased.contains("goal") || lowercased.contains("plan") || lowercased.contains("want to") {
            return .goals
        } else if lowercased.contains("friend") || lowercased.contains("family") || lowercased.contains("partner") {
            return .relationships
        } else if lowercased.contains("achieved") || lowercased.contains("accomplished") || lowercased.contains("success") {
            return .achievements
        } else if lowercased.contains("challenge") || lowercased.contains("difficult") || lowercased.contains("struggle") {
            return .challenges
        } else if lowercased.contains("like") || lowercased.contains("prefer") || lowercased.contains("enjoy") {
            return .preferences
        } else if lowercased.contains("daily") || lowercased.contains("routine") || lowercased.contains("usually") {
            return .routine
        }
        
        return .personal
    }
    
    private func determineImportance(_ content: String) -> Int {
        let lowercased = content.lowercased()
        
        // High importance keywords
        if lowercased.contains("important") || lowercased.contains("significant") || 
           lowercased.contains("major") || lowercased.contains("big") {
            return 5
        }
        
        // Medium-high importance
        if lowercased.contains("goal") || lowercased.contains("decided") || 
           lowercased.contains("realized") || lowercased.contains("learned") {
            return 4
        }
        
        // Default medium importance
        return 3
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

private struct ExtractedMemory: Codable {
    let content: String
    let category: String
    let importance: Int
}