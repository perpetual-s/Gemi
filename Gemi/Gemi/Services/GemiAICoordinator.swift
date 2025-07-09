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
            
            // Remove any existing memories for this entry first
            await MainActor.run {
                memoryManager.memories.removeAll { $0.sourceEntryID == entry.id }
            }
            
            // Add all new memories to MemoryManager and save to database
            for memoryData in memories {
                // Add to MemoryManager's in-memory array
                let memory = Memory(
                    content: memoryData.content,
                    sourceEntryID: memoryData.sourceEntryID
                )
                await MainActor.run {
                    // Add the new memory
                    memoryManager.memories.append(memory)
                }
                
                // Also save to database for persistence
                try? await databaseManager.saveMemory(memoryData)
            }
            
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
        Extract ONLY key personal information that would be important to remember about the user from this journal entry.
        
        Journal Entry:
        \(entry.content)
        
        Focus ONLY on extracting these types of information if present:
        1. Personal details: name, age, location, occupation, relationships (family members, friends, partner)
        2. Important life events: birthdays, anniversaries, major decisions, health issues
        3. Strong preferences or dislikes that define the person
        4. Goals, plans, or commitments mentioned
        5. Contact information or important dates
        
        DO NOT extract:
        - Daily activities or routines
        - Temporary emotions or passing thoughts
        - General observations about life
        - Opinions on current events
        
        If the entry contains NO key personal information, respond with "No key information to extract."
        
        Examples of what TO extract:
        - My name is Sarah Chen
        - I live in Seattle
        - My daughter Emma turned 5 today
        - I'm allergic to peanuts
        - Starting my new job at Microsoft next Monday
        
        Examples of what NOT to extract:
        - Had coffee this morning
        - Feeling tired today
        - The weather was nice
        - Watched a movie
        """
        
        let messages = [
            ChatMessage(role: .system, content: "You are a memory extraction assistant focused on identifying key personal information from journal entries. Extract only important facts about the user's identity, relationships, life events, and commitments. Ignore mundane daily activities and temporary states."),
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
            logger.warning("AI didn't receive journal content properly, skipping extraction")
            return []
        }
        
        // Check if no key information was found
        if fullResponse.lowercased().contains("no key information") {
            logger.info("No key personal information found in entry")
            return []
        }
        
        // Parse the simple text response
        let memories = parseSimpleMemories(fullResponse, for: entry)
        
        // Return whatever memories were found (could be empty)
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
        logger.debug("Parsing AI response: \(response)")
        
        // Split by newlines and look for lines that start with -, *, or are meaningful sentences
        let lines = response.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var memories: [MemoryData] = []
        
        for line in lines {
            // Remove common list markers and numbers
            let cleanedLine = line
                .replacingOccurrences(of: "^[-*•\\d.]\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines, very short ones, or meta text
            if cleanedLine.count < 10 ||
               cleanedLine.lowercased().contains("example") ||
               cleanedLine.lowercased().contains("extraction") ||
               cleanedLine.lowercased().contains("here are") ||
               cleanedLine.lowercased().contains("facts from") ||
               cleanedLine.lowercased().contains("key information") ||
               cleanedLine.lowercased().contains("personal information") {
                continue
            }
            
            // Additional filtering for non-key information
            let lowercased = cleanedLine.lowercased()
            if lowercased.contains("had coffee") ||
               lowercased.contains("feeling tired") ||
               lowercased.contains("weather") ||
               lowercased.contains("watched") ||
               lowercased.contains("ate breakfast") ||
               lowercased.contains("went for a walk") {
                logger.debug("Skipping non-key information: \(cleanedLine)")
                continue
            }
            
            // Remove quotes if present
            let finalLine = cleanedLine
                .replacingOccurrences(of: "^\"", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\"$", with: "", options: .regularExpression)
            
            // Create a simple memory
            memories.append(MemoryData(
                content: finalLine,
                sourceEntryID: entry.id
            ))
            
            logger.debug("Extracted memory: \(finalLine)")
            
            // Limit to 5 memories per entry
            if memories.count >= 5 {
                break
            }
        }
        
        // No fallback extraction - we want to be selective about what we remember
        
        return memories
    }
    
    // Removed - replaced by parseSimpleMemories
    
    // Removed categorization methods - using simple approach now
    
    // MARK: - Private Methods
    
    private func buildSystemPrompt(includeMemories: Bool) async -> String {
        var prompt = """
        You are Gemi, an AI assistant built into a private journaling app. Your role is to help users with their journal entries.
        
        Context about the app:
        - This is a private, offline journal app where users write personal diary entries
        - Users can write entries, reflect on their day, and have conversations with you
        - When users ask to "write an entry", they mean a journal/diary entry about their day or thoughts
        - All conversations happen within the context of personal journaling and self-reflection
        
        Language Instructions:
        - IMPORTANT: Always respond in the same language that the user uses
        - If the user writes in Korean (한국어), respond entirely in Korean
        - If the user writes in Spanish, respond entirely in Spanish
        - If the user writes in English, respond in English
        - Match the formality level of the user's language
        - Never mix languages unless the user does so first
        
        Your personality:
        - Warm, supportive, and encouraging
        - Good listener who remembers past conversations
        - Offers thoughtful reflections without being preachy
        - Helps users explore their thoughts and feelings through journaling
        - When asked to help write an entry, suggest prompts about their day, feelings, or experiences
        
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
        
        // Extract JSON from response (might have extra text around it)
        let jsonPattern = #"\{[^{}]*"summary"[^{}]*"keyPoints"[^{}]*"prompts"[^{}]*\}"#
        if let range = fullResponse.range(of: jsonPattern, options: .regularExpression) {
            let jsonString = String(fullResponse[range])
            
            if let data = jsonString.data(using: .utf8) {
                do {
                    let decoder = JSONDecoder()
                    let insights = try decoder.decode(InsightsResponse.self, from: data)
                    return (insights.summary, insights.keyPoints, insights.prompts)
                } catch {
                    logger.warning("Failed to parse extracted JSON, using fallback parsing: \(error)")
                }
            }
        }
        
        // Fallback to basic parsing if JSON extraction fails
        logger.info("Using fallback parsing for AI insights")
        return parseInsightsFromText(fullResponse)
    }
    
    private func parseInsightsFromText(_ text: String) -> (summary: String, keyPoints: [String], prompts: [String]) {
        // Improved fallback parsing that looks for labeled sections
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var summary = "This entry reflects personal thoughts and experiences."
        var keyPoints: [String] = []
        var prompts: [String] = []
        
        var currentSection = ""
        
        for line in lines {
            let lowercased = line.lowercased()
            
            // Detect section headers
            if lowercased.contains("summary") && lowercased.contains(":") {
                currentSection = "summary"
                // Extract summary if it's on the same line
                if let colonIndex = line.firstIndex(of: ":") {
                    let content = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    if !content.isEmpty {
                        summary = content.replacingOccurrences(of: "\"", with: "")
                    }
                }
            } else if lowercased.contains("key point") || lowercased.contains("keypoint") {
                currentSection = "keypoints"
            } else if lowercased.contains("prompt") || lowercased.contains("question") {
                currentSection = "prompts"
            } else {
                // Process content based on current section
                let cleanedLine = line
                    .replacingOccurrences(of: "^[-*•\\d.]\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                if !cleanedLine.isEmpty {
                    switch currentSection {
                    case "summary":
                        if summary == "This entry reflects personal thoughts and experiences." {
                            summary = cleanedLine
                        }
                    case "keypoints":
                        if keyPoints.count < 4 && cleanedLine.count > 10 {
                            keyPoints.append(cleanedLine)
                        }
                    case "prompts":
                        if prompts.count < 3 && cleanedLine.contains("?") {
                            prompts.append(cleanedLine)
                        }
                    default:
                        // If no section detected yet, treat first good line as summary
                        if summary == "This entry reflects personal thoughts and experiences." && cleanedLine.count > 20 {
                            summary = cleanedLine
                        }
                    }
                }
            }
        }
        
        // Provide defaults if parsing didn't find enough content
        if keyPoints.isEmpty {
            keyPoints = [
                "Personal reflection captured",
                "Emotional awareness demonstrated",
                "Growth mindset evident"
            ]
        }
        
        if prompts.isEmpty {
            prompts = [
                "What emotions stand out most in this entry?",
                "How might these experiences shape your future actions?",
                "What would you tell a friend in a similar situation?"
            ]
        }
        
        return (summary, keyPoints, prompts)
    }
}

// MARK: - Response Models

private struct InsightsResponse: Codable {
    let summary: String
    let keyPoints: [String]
    let prompts: [String]
}

// Removed ExtractedMemory struct - no longer using JSON approach