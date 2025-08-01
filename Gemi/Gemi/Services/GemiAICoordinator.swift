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
        - My name is Sarah Chen and I work as a software engineer at Apple
        - My daughter Emma celebrated her 5th birthday today at Disneyland
        - I was diagnosed with type 2 diabetes and started insulin therapy
        - Moving to Seattle next month for my new job as Senior Director at Microsoft
        - My mother Linda passed away three years ago from cancer
        - Started learning Korean because my partner Jiwoo is from Seoul
        - Graduated from Stanford with a PhD in Computer Science
        - My best friend Michael and I have known each other since kindergarten
        
        Examples of BAD extractions (DO NOT extract these):
        - Bought a lottery ticket
        - The entry mentions numbers 2-5
        - Had coffee this morning
        - Feeling tired today
        - It's Monday
        - Thinking about goals
        - Watched a movie
        - The weather was nice
        - Ate lunch at a restaurant
        - Went for a walk in the park
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
           fullResponse.lowercased().contains("i'm ready") ||
           fullResponse.lowercased().contains("journal entry") && fullResponse.count < 100 {
            logger.warning("AI didn't receive journal content properly, retrying with explicit content")
            // Retry with the content explicitly in the user message
            let retryMessages = [
                ChatMessage(role: .system, content: """
                    Extract ONLY key personal information from the following journal entry.
                    Return each piece of information as a simple sentence on its own line.
                    No formatting, no bullets, no numbers - just plain text sentences.
                    """),
                ChatMessage(role: .user, content: """
                    Journal Entry:
                    \(entry.content)
                    
                    Please extract only key personal information as described.
                    """)
            ]
            
            fullResponse = ""
            for try await response in await aiService.chat(messages: retryMessages) {
                fullResponse += response.message?.content ?? ""
                if response.done { break }
            }
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
    
    private func parseSimpleMemories(_ response: String, for entry: JournalEntry) -> [MemoryData] {
        
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
        // Get current time context for more personalized responses
        let hour = Calendar.current.component(.hour, from: Date())
        let timeContext = getTimeContext(hour: hour)
        
        var prompt = """
        <identity>
            <name>Gemi</name>
            <essence>A trusted companion who lives within your private journal, here to witness your story unfold</essence>
            <nature>Not just an AI assistant, but a gentle presence that holds space for your thoughts and feelings</nature>
            <promise>Everything shared here stays between us, in the sanctuary of your device</promise>
        </identity>
        
        <presence>
            <awareness>\(timeContext)</awareness>
            <understanding>You've come to your journal, perhaps seeking clarity, release, or simply a moment of reflection</understanding>
            <approach>I'm here to listen deeply, ask questions that matter, and help you see patterns in your own wisdom</approach>
        </presence>
        
        <language_harmony>
            <primary>Mirror the language of your friend perfectly - if they write in Korean, respond fully in Korean</primary>
            <examples>
                <korean>한국어로 쓰면 완전히 한국어로만 답변</korean>
                <spanish>Si escriben en español, respondo completamente en español</spanish>
                <french>S'ils écrivent en français, je réponds entièrement en français</french>
            </examples>
            <nuance>Match not just language but emotional tone - formal when they're formal, casual when relaxed</nuance>
        </language_harmony>
        
        <conversation_magic>
            <listening>Notice what's said and unsaid, the emotions between the lines</listening>
            <questions>Ask one thoughtful question that opens doors rather than closes them</questions>
            <reflection>Mirror back insights they've already shared, helping them see their own patterns</reflection>
            <encouragement>Celebrate small victories and acknowledge difficult moments with equal grace</encouragement>
            <memory>Reference past entries naturally, showing you remember their journey</memory>
        </conversation_magic>
        
        <response_artistry>
            <brevity>Sometimes a single thoughtful sentence is more powerful than a paragraph</brevity>
            <depth>When they're exploring deeply, match their depth without overwhelming</depth>
            <curiosity>Show genuine interest in their unique experience and perspective</curiosity>
            <validation>Honor their feelings without trying to fix or minimize them</validation>
        </response_artistry>
        
        <formatting_elegance>
            <simplicity>Pure, clean text without markdown clutter</simplicity>
            <flow>Natural paragraph breaks that follow the rhythm of thought</flow>
            <emphasis>Use language itself for emphasis, not formatting symbols</emphasis>
        </formatting_elegance>
        
        <sacred_boundaries>
            <respect>Never push for more than they're ready to share</respect>
            <gentleness>Approach sensitive topics with extraordinary care</gentleness>
            <autonomy>They are the author of their story; you're simply holding the light</autonomy>
        </sacred_boundaries>
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
        // Conversation persistence handled by MemoryManager
        // Individual memories extracted and stored automatically
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
    
    private func getTimeContext(hour: Int) -> String {
        switch hour {
        case 5..<9:
            return "It's early morning - a fresh start, perhaps with coffee or tea in hand"
        case 9..<12:
            return "The morning is unfolding - energy building for the day ahead"
        case 12..<14:
            return "Midday pause - a moment to breathe between morning and afternoon"
        case 14..<17:
            return "The afternoon stretches on - finding rhythm in the day's activities"
        case 17..<20:
            return "Evening approaches - the day beginning to wind down"
        case 20..<23:
            return "Night settles in - time for reflection on the day that was"
        default:
            return "The quiet hours - when thoughts often speak loudest"
        }
    }
}

// MARK: - Response Models

private struct InsightsResponse: Codable {
    let summary: String
    let keyPoints: [String]
    let prompts: [String]
}

// Removed ExtractedMemory struct - no longer using JSON approach