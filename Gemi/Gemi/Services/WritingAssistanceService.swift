import Foundation
import Combine

/// Specialized AI service for writing assistance features
@MainActor
final class WritingAssistanceService: ObservableObject {
    @Published var isProcessing = false
    @Published var lastError: Error?
    
    private let databaseManager = DatabaseManager.shared
    private let memoryManager = MemoryManager.shared
    
    enum WritingContext {
        case continuation
        case ideation
        case styleImprovement
        case emotionalExploration
        case writersBlock
    }
    
    struct WritingAnalysis {
        let tone: EmotionalTone
        let clarity: ClarityScore
        let suggestions: [String]
        let continuations: [String]
        
        enum EmotionalTone {
            case positive, negative, neutral, mixed
        }
        
        struct ClarityScore {
            let score: Double // 0-1
            let issues: [String]
        }
    }
    
    // MARK: - Public Methods
    
    /// Generate contextual writing suggestions based on current text
    func generateSuggestions(
        for text: String,
        previousContext: String? = nil,
        context: WritingContext
    ) async throws -> [String] {
        isProcessing = true
        defer { isProcessing = false }
        
        let prompt = buildWritingPrompt(
            currentText: text,
            previousContext: previousContext,
            context: context
        )
        
        do {
            // Use chat API for suggestions with contextual temperature
            let messages = [
                ChatMessage(role: .system, content: """
                You are a helpful writing assistant for a personal journal app.
                
                CRITICAL RULE: Always respond in the SAME LANGUAGE as the user's text.
                - Detect the language from the text content, not system settings
                - Maintain consistency - if the text is in English, respond only in English
                - Never mix languages unless the user's text explicitly mixes them
                
                IMPORTANT: Never use markdown formatting like **bold** or *italic*.
                Always respond in plain, natural language without any formatting symbols.
                """),
                ChatMessage(role: .user, content: prompt)
            ]
            
            var fullResponse = ""
            let stream = await AIService.shared.chatWithContext(messages: messages)
            
            for try await response in stream {
                if let content = response.message?.content {
                    fullResponse += content
                }
            }
            
            return parseWritingSuggestions(from: fullResponse)
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Analyze text for emotional tone and writing quality
    func analyzeWriting(_ text: String) async throws -> WritingAnalysis {
        isProcessing = true
        defer { isProcessing = false }
        
        let prompt = """
        Analyze this journal entry text and provide:
        1. Emotional tone (positive/negative/neutral/mixed)
        2. Writing clarity issues if any
        3. 2-3 specific suggestions for improvement
        4. 2 natural ways to continue the thought
        
        Text: "\(text)"
        
        Format your response as:
        TONE: [tone]
        CLARITY: [score 0-1]
        ISSUES: [comma-separated issues or "none"]
        SUGGESTIONS:
        - [suggestion 1]
        - [suggestion 2]
        - [suggestion 3]
        CONTINUATIONS:
        - [continuation 1]
        - [continuation 2]
        """
        
        let messages = [
            ChatMessage(role: .system, content: """
            You are an analytical writing assistant.
            
            CRITICAL RULE: Respond in the SAME LANGUAGE as the text being analyzed.
            - Detect language from the PROVIDED TEXT only
            - If the text is in English, respond in English
            - Never switch languages
            
            Never use markdown formatting symbols like asterisks.
            Respond in clear, plain text only.
            """),
            ChatMessage(role: .user, content: prompt)
        ]
        
        var response = ""
        let stream = await AIService.shared.chat(messages: messages)
        
        for try await chunk in stream {
            if let content = chunk.message?.content {
                response += content
            }
        }
        
        return parseWritingAnalysis(from: response)
    }
    
    /// Generate a natural continuation of the current text
    func continueWriting(
        from text: String,
        style: WritingStyle = .reflective
    ) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        // Analyze the last few sentences for context
        let recentContext = extractRecentContext(from: text)
        
        let prompt = """
        Continue this journal entry naturally in a \(style.rawValue) style.
        Match the tone and voice of the existing text.
        
        Context: "\(recentContext)"
        
        Write 1-2 sentences that flow naturally from this thought:
        """
        
        let messages = [
            ChatMessage(role: .system, content: """
            You are a creative writing assistant that continues journal entries naturally.
            
            CRITICAL RULE: Continue in the SAME LANGUAGE as the existing text.
            - Detect the language from the text provided
            - Continue writing in that exact language
            
            Always use plain text without any markdown formatting or symbols.
            """),
            ChatMessage(role: .user, content: prompt)
        ]
        
        var response = ""
        let stream = await AIService.shared.chatWithContext(messages: messages)
        
        for try await chunk in stream {
            if let content = chunk.message?.content {
                response += content
            }
        }
        
        return response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    /// Generate reflective questions based on the current text
    func generateReflectiveQuestions(for text: String) async throws -> [String] {
        isProcessing = true
        defer { isProcessing = false }
        
        let prompt = """
        Based on this journal entry, generate 3 thoughtful questions that would help the writer explore their thoughts and feelings more deeply.
        
        Entry: "\(text)"
        
        Format each question on a new line starting with "- "
        Make questions specific to the content, not generic.
        """
        
        let messages = [
            ChatMessage(role: .system, content: """
            You are a thoughtful writing assistant that asks deep, reflective questions.
            
            CRITICAL RULE: Ask questions in the SAME LANGUAGE as the journal entry.
            - Detect and match the language of the user's text exactly
            
            Format your responses in plain text without any markdown symbols.
            """),
            ChatMessage(role: .user, content: prompt)
        ]
        
        var response = ""
        let stream = await AIService.shared.chatWithContext(messages: messages)
        
        for try await chunk in stream {
            if let content = chunk.message?.content {
                response += content
            }
        }
        
        return parseListItems(from: response)
    }
    
    /// Get writing prompts for overcoming writer's block
    func getWritersBlockPrompts(
        mood: String? = nil,
        recentTopics: [String] = []
    ) async throws -> [WritingPrompt] {
        isProcessing = true
        defer { isProcessing = false }
        
        let recentContext = recentTopics.isEmpty ? "general journaling" : recentTopics.joined(separator: ", ")
        let moodContext = mood ?? "reflective"
        
        let prompt = """
        Generate 4 creative writing prompts for someone experiencing writer's block in their journal.
        Consider their current mood: \(moodContext)
        Recent topics they've written about: \(recentContext)
        
        Make prompts specific, engaging, and thought-provoking.
        Format as:
        1. [TITLE]: [prompt description]
        2. [TITLE]: [prompt description]
        3. [TITLE]: [prompt description]
        4. [TITLE]: [prompt description]
        """
        
        let messages = [
            ChatMessage(role: .system, content: """
            You are a creative writing prompt generator.
            
            CRITICAL RULE: Generate prompts in the detected language.
            - Analyze the language of any provided text or topics
            - Create prompts in that same language
            
            Never use asterisks or markdown formatting in your responses.
            Write all prompts in clear, plain language.
            """),
            ChatMessage(role: .user, content: prompt)
        ]
        
        var response = ""
        let stream = await AIService.shared.chatWithContext(messages: messages)
        
        for try await chunk in stream {
            if let content = chunk.message?.content {
                response += content
            }
        }
        
        return parseWritingPrompts(from: response)
    }
    
    // MARK: - Private Methods
    
    private func buildWritingPrompt(
        currentText: String,
        previousContext: String?,
        context: WritingContext
    ) -> String {
        let basePrompt = """
        <instructions>
        You are Gemi, an intelligent writing assistant powered by Gemma 3n.
        You excel at understanding context, emotions, and creative expression across 140+ languages.
        Provide helpful, specific suggestions that honor the writer's voice and emotional state.
        
        <capabilities>
        - Multilingual understanding: Respond in the same language as the user
        - Emotional intelligence: Recognize and respond to emotional cues
        - Creative expression: Generate vivid, engaging continuations
        - Cultural awareness: Respect diverse perspectives and expressions
        - Language support: Full support for 140+ languages
        </capabilities>
        
        <language_detection>
        CRITICAL LANGUAGE RULE:
        - Detect the language from the CURRENT TEXT only
        - Respond in the SAME language as detected
        - If the text is in English, respond ONLY in English
        - Never switch languages unless the user's text switches
        </language_detection>
        
        <format_rules>
        - DO NOT use markdown formatting like **bold** or *italic*
        - DO NOT use asterisks for emphasis
        - Write in plain, natural language
        - Use simple punctuation and clear sentences
        - Each suggestion should be a complete thought
        - Match the writer's tone and style naturally
        </format_rules>
        </instructions>
        
        """
        
        switch context {
        case .continuation:
            return basePrompt + """
            <task>
            The user wants to continue their thought. Analyze the text and suggest 3 natural ways to continue.
            </task>
            
            <context>
            Current text: "\(currentText)"
            \(previousContext.map { "Previous paragraph: \"\($0)\"" } ?? "")
            
            LANGUAGE INSTRUCTION: Respond in the same language as the current text above.
            </context>
            
            <requirements>
            Provide 3 different continuations that:
            1. Flow naturally from the existing text
            2. Maintain the same tone and style
            3. Help develop the thought further
            
            Format each continuation on a new line.
            
            FORMATTING REMINDER:
            - Use plain text only, no markdown formatting
            - NO asterisks (*) or underscores (_) for emphasis
            - Just natural, plain language
            </requirements>
            """
            
        case .ideation:
            return basePrompt + """
            <task>
            The user is looking for ideas to explore. Based on their current writing, suggest interesting angles or perspectives.
            </task>
            
            <context>
            Current text: "\(currentText)"
            
            LANGUAGE INSTRUCTION: Respond in the same language as the current text above.
            </context>
            
            <requirements>
            Provide 3-4 specific ideas that:
            1. Connect to what they've written
            2. Encourage deeper reflection
            3. Open new avenues of thought
            
            Format each idea on a new line starting with a simple dash.
            
            FORMATTING REMINDER:
            - Use plain language without any formatting symbols
            - NO markdown like *emphasis* or **bold**
            - NO underscores or other formatting marks
            - Just clear, natural text
            </requirements>
            """
            
        case .styleImprovement:
            
            return basePrompt + """
            <task>
            The user wants to improve their writing style. Analyze the text and suggest specific improvements.
            </task>
            
            <context>
            Current text: "\(currentText)"
            
            LANGUAGE INSTRUCTION:
            - Analyze the language of the text above
            - Respond ONLY in the same language as the text
            - If the text is in English, respond in English
            - Do not switch languages for any reason
            </context>
            
            <requirements>
            Provide 3 actionable suggestions to improve:
            1. Clarity and flow
            2. Emotional expression
            3. Descriptive detail
            
            Be specific about what to change and why.
            Format each suggestion on a new line.
            
            CRITICAL FORMATTING RULES:
            - Write in clear, plain language WITHOUT any formatting marks
            - DO NOT use asterisks for emphasis like *this* or **this**
            - DO NOT use underscores for emphasis like _this_ or __this__
            - DO NOT use any markdown formatting whatsoever
            - Just use plain, natural language
            
            Examples of what NOT to do:
            - WRONG: "Add *more descriptive* language"
            - WRONG: "Make this **bolder** in tone"
            - RIGHT: "Add more descriptive language"
            - RIGHT: "Make this bolder in tone"
            
            FINAL REMINDER: The text "\(currentText)" is in a specific language. You MUST respond in that exact same language using PLAIN TEXT ONLY.
            </requirements>
            """
            
        case .emotionalExploration:
            return basePrompt + """
            <task>
            Help the user explore the emotions in their writing more deeply.
            </task>
            
            <context>
            Text: "\(currentText)"
            
            LANGUAGE INSTRUCTION: Respond in the same language as the text above.
            </context>
            
            <requirements>
            Provide 3 prompts that:
            1. Help identify underlying feelings
            2. Explore physical sensations
            3. Connect to deeper meanings
            
            Format each prompt as a gentle question or suggestion.
            Avoid all markdown symbols and formatting marks.
            </requirements>
            """
            
        case .writersBlock:
            return basePrompt + """
            <task>
            The user is experiencing writer's block. Provide gentle, creative prompts to get them writing again.
            </task>
            
            <context>
            Recent text (if any): "\(currentText)"
            
            LANGUAGE INSTRUCTION: If text is provided above, respond in that same language. If no text, use the default language.
            </context>
            
            <requirements>
            Suggest 3 approaches:
            1. A sensory-based prompt
            2. A memory trigger
            3. A "what if" scenario
            
            Make each prompt specific and engaging.
            Use natural language only - no asterisks or formatting symbols.
            </requirements>
            """
        }
    }
    
    private func parseWritingSuggestions(from response: String) -> [String] {
        response
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line in
                // Remove common prefixes
                var cleaned = line
                for prefix in ["- ", "• ", "* ", "1. ", "2. ", "3. ", "4. "] {
                    if cleaned.hasPrefix(prefix) {
                        cleaned = String(cleaned.dropFirst(prefix.count))
                        break
                    }
                }
                return cleaned
            }
    }
    
    private func parseWritingAnalysis(from response: String) -> WritingAnalysis {
        let lines = response.components(separatedBy: .newlines)
        var tone: WritingAnalysis.EmotionalTone = .neutral
        var clarityScore = 1.0
        var issues: [String] = []
        var suggestions: [String] = []
        var continuations: [String] = []
        
        var currentSection = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.hasPrefix("TONE:") {
                let toneStr = trimmed.replacingOccurrences(of: "TONE:", with: "").trimmingCharacters(in: .whitespaces).lowercased()
                tone = parseTone(from: toneStr)
            } else if trimmed.hasPrefix("CLARITY:") {
                let scoreStr = trimmed.replacingOccurrences(of: "CLARITY:", with: "").trimmingCharacters(in: .whitespaces)
                clarityScore = Double(scoreStr) ?? 1.0
            } else if trimmed.hasPrefix("ISSUES:") {
                let issuesStr = trimmed.replacingOccurrences(of: "ISSUES:", with: "").trimmingCharacters(in: .whitespaces)
                if issuesStr.lowercased() != "none" {
                    issues = issuesStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
                currentSection = ""
            } else if trimmed == "SUGGESTIONS:" {
                currentSection = "suggestions"
            } else if trimmed == "CONTINUATIONS:" {
                currentSection = "continuations"
            } else if trimmed.hasPrefix("- ") {
                let item = String(trimmed.dropFirst(2))
                switch currentSection {
                case "suggestions":
                    suggestions.append(item)
                case "continuations":
                    continuations.append(item)
                default:
                    break
                }
            }
        }
        
        return WritingAnalysis(
            tone: tone,
            clarity: WritingAnalysis.ClarityScore(score: clarityScore, issues: issues),
            suggestions: suggestions,
            continuations: continuations
        )
    }
    
    private func parseTone(from string: String) -> WritingAnalysis.EmotionalTone {
        switch string {
        case "positive": return .positive
        case "negative": return .negative
        case "mixed": return .mixed
        default: return .neutral
        }
    }
    
    private func parseListItems(from response: String) -> [String] {
        response
            .components(separatedBy: .newlines)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("- ") {
                    return String(trimmed.dropFirst(2))
                } else if trimmed.hasPrefix("• ") {
                    return String(trimmed.dropFirst(2))
                }
                return nil
            }
    }
    
    private func parseWritingPrompts(from response: String) -> [WritingPrompt] {
        let lines = response.components(separatedBy: .newlines)
        var prompts: [WritingPrompt] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Match patterns like "1. [TITLE]: [description]" or "1. TITLE: description"
            if let match = trimmed.firstMatch(of: /^\d+\.\s*\[?([^\]:\n]+)\]?:\s*(.+)$/) {
                let title = String(match.1).trimmingCharacters(in: .whitespaces)
                let description = String(match.2).trimmingCharacters(in: .whitespaces)
                
                prompts.append(WritingPrompt(
                    id: UUID(),
                    title: title,
                    prompt: description,
                    category: "AI Generated",
                    difficulty: .medium
                ))
            }
        }
        
        return prompts
    }
    
    private func extractRecentContext(from text: String, sentenceCount: Int = 2) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let recentSentences = sentences.suffix(sentenceCount)
        return recentSentences.joined(separator: ". ")
    }
}

// MARK: - Supporting Types

extension WritingAssistanceService {
    enum WritingStyle: String {
        case reflective = "reflective"
        case narrative = "narrative"
        case analytical = "analytical"
        case emotional = "emotional"
        case descriptive = "descriptive"
    }
    
    struct WritingPrompt: Identifiable {
        let id: UUID
        let title: String
        let prompt: String
        let category: String
        let difficulty: Difficulty
        
        enum Difficulty {
            case easy, medium, hard
        }
    }
}

// MARK: - WritingContext Extensions

extension WritingAssistanceService.WritingContext {
    var temperature: Float {
        switch self {
        case .continuation: return 0.7
        case .ideation: return 0.8
        case .styleImprovement: return 0.3
        case .emotionalExploration: return 0.6
        case .writersBlock: return 0.9
        }
    }
}