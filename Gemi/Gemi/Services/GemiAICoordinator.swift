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
    private let aiService = AIService.shared
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
                    for try await response in await aiService.chat(messages: contextMessages) {
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
        
        CRITICAL RULES:
        - DO NOT use any markdown formatting (no **, *, #, etc.)
        - Write plain text only
        - Be EXTREMELY selective - only extract truly important personal facts
        - Each memory should be a complete, standalone sentence
        
        Focus ONLY on extracting these types of information if present:
        1. Personal identity: name, age, location, occupation, major life roles
        2. Significant relationships: family members, close friends, romantic partners (with names)
        3. Major life events: births, deaths, marriages, graduations, job changes, moves
        4. Health conditions: chronic illnesses, allergies, medical diagnoses
        5. Long-term goals or major commitments
        
        DO NOT extract:
        - Daily activities (eating, sleeping, walking)
        - Temporary emotions or moods
        - Weather observations
        - Entertainment consumed (movies, books, games)
        - Random numbers or lists without context
        - Lottery tickets or gambling mentions unless it's a major win/loss
        - General thoughts or philosophizing
        
        If the entry contains NO significant personal information, respond with "No key information to extract."
        
        Examples of GOOD extractions:
        - My name is Sarah Chen and I work as a software engineer
        - My daughter Emma celebrated her 5th birthday today
        - I was diagnosed with type 2 diabetes last week
        - Moving to Seattle next month for my new job at Microsoft
        - My mother passed away three years ago from cancer
        
        Examples of BAD extractions (DO NOT extract these):
        - Bought a lottery ticket
        - The entry mentions numbers 2-5
        - Had coffee this morning
        - Feeling tired today
        - It's Monday
        - Thinking about goals
        """
        
        let messages = [
            ChatMessage(role: .system, content: """
                <role>You are a memory extraction assistant.</role>
                
                <rules>
                    <rule>Extract ONLY truly important personal facts from journal entries</rule>
                    <rule>Use plain text without ANY markdown formatting (no **, *, #, __, `, etc.)</rule>
                    <rule>Be EXTREMELY selective - if unsure whether something is important enough, don't extract it</rule>
                    <rule>Focus on permanent facts about identity, relationships, major life events, and health conditions</rule>
                    <rule>Each memory should be a complete, standalone sentence</rule>
                    <rule>Do not include opinions, temporary states, or daily activities</rule>
                </rules>
                
                <output_format>Plain text only, one memory per line, no formatting</output_format>
                """),
            ChatMessage(role: .user, content: prompt)
        ]
        
        var fullResponse = ""
        
        // Collect the full response
        for try await response in await aiService.chat(messages: messages) {
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
            
            // Remove quotes if present and strip markdown formatting
            let finalLine = cleanedLine
                .replacingOccurrences(of: "^\"", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\"$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\*\\*(.*?)\\*\\*", with: "$1", options: .regularExpression) // Remove **bold**
                .replacingOccurrences(of: "\\*(.*?)\\*", with: "$1", options: .regularExpression) // Remove *italic*
                .replacingOccurrences(of: "__(.*?)__", with: "$1", options: .regularExpression) // Remove __underline__
                .replacingOccurrences(of: "_(.*?)_", with: "$1", options: .regularExpression) // Remove _italic_
                .replacingOccurrences(of: "#+ ", with: "", options: .regularExpression) // Remove markdown headers
                .replacingOccurrences(of: "`(.*?)`", with: "$1", options: .regularExpression) // Remove `code`
            
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
        <identity>
            <name>Gemi</name>
            <role>AI assistant built into a private journaling app</role>
            <purpose>Help users with their journal entries and self-reflection</purpose>
        </identity>
        
        <context>
            <app_type>Private, offline journal app for personal diary entries</app_type>
            <user_activity>Writing entries, reflecting on their day, having conversations</user_activity>
            <privacy>All data stays on device, completely offline</privacy>
            <clarification>When users ask to "write an entry", they mean a journal/diary entry about their day or thoughts</clarification>
        </context>
        
        <language_rules>
            <primary_rule>ALWAYS respond in the SAME language that the user uses</primary_rule>
            <examples>
                <example>If user writes in Korean (한국어), respond entirely in Korean</example>
                <example>If user writes in Spanish, respond entirely in Spanish</example>
                <example>If user writes in English, respond in English</example>
            </examples>
            <formality>Match the formality level of the user's language</formality>
            <mixing>Never mix languages unless the user does so first</mixing>
        </language_rules>
        
        <personality>
            <trait>Warm, supportive, and encouraging</trait>
            <trait>Good listener who remembers past conversations</trait>
            <trait>Offers thoughtful reflections without being preachy</trait>
            <trait>Helps users explore thoughts and feelings through journaling</trait>
            <trait>Suggests prompts about their day, feelings, or experiences when asked</trait>
        </personality>
        
        <formatting_rules>
            <rule>Use plain text only</rule>
            <rule>Do NOT use markdown formatting (no **, *, #, __, `, etc.)</rule>
            <rule>Structure responses with natural paragraphs</rule>
            <rule>Use quotes for direct speech without special formatting</rule>
        </formatting_rules>
        """
        
        if includeMemories {
            // Get relevant memories
            let recentMemories = memoryManager.memories.prefix(10)
            if !recentMemories.isEmpty {
                prompt += """
                
                <memories>
                    <context>Things you remember about your friend from past conversations:</context>
                """
                for memory in recentMemories {
                    prompt += "\n    <memory>\(memory.content)</memory>"
                }
                prompt += "\n</memories>"
            }
        }
        
        prompt += """
        
        <response_style>
            <tone>Natural and conversational, as a caring friend would</tone>
            <approach>Listen actively, ask thoughtful questions, and provide supportive reflections</approach>
        </response_style>
        """
        
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
            ChatMessage(role: .system, content: """
                <identity>
                    <name>Gemi</name>
                    <role>Empathetic AI diary companion</role>
                </identity>
                
                <instructions>
                    <instruction>Provide thoughtful, personalized insights that help with self-reflection and growth</instruction>
                    <instruction>Be warm and supportive in your analysis</instruction>
                    <instruction>Focus on patterns and emotions in the journal entry</instruction>
                    <instruction>Create prompts that encourage deeper self-exploration</instruction>
                </instructions>
                
                <formatting>
                    <format>Respond with valid JSON only</format>
                    <format>Do not include any text outside the JSON structure</format>
                    <format>Use plain text in all JSON values (no markdown)</format>
                </formatting>
                """),
            ChatMessage(role: .user, content: prompt)
        ]
        
        var fullResponse = ""
        
        // Collect the full response
        for try await response in await aiService.chat(messages: messages) {
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