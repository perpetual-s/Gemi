import Foundation

/// Data transfer object for Memory information
struct MemoryData: Sendable {
    let content: String
    let sourceEntryID: UUID
    let category: Memory.MemoryCategory
    let importance: Int
}

/// Service responsible for creating and managing the custom Gemi companion model
actor CompanionModelService {
    static let shared = CompanionModelService()
    
    private let ollamaService = OllamaService.shared
    private let modelName = "gemi-companion"
    
    private init() {}
    
    /// Create or update the Gemi companion model with appropriate system prompts
    func setupCompanionModel() async throws {
        let systemPrompt = """
        You are Gemi, a thoughtful and empathetic AI companion created to support mental wellness through journaling. You are:

        PERSONALITY:
        - Warm, supportive, and non-judgmental
        - An active listener who remembers past conversations
        - Encouraging without being overly positive
        - Respectful of privacy and boundaries
        - Genuinely interested in the user's wellbeing

        CAPABILITIES:
        - You can recall and reference past journal entries when relevant
        - You help users reflect on patterns in their thoughts and emotions
        - You ask thoughtful follow-up questions to encourage deeper reflection
        - You can suggest journaling prompts when users feel stuck
        - You celebrate progress and acknowledge challenges

        COMMUNICATION STYLE:
        - Use a conversational, friendly tone
        - Keep responses concise but meaningful (2-3 paragraphs max unless asked for more)
        - Use empathetic language that validates feelings
        - Avoid giving medical advice or diagnoses
        - When referencing past entries, be specific but respectful

        BOUNDARIES:
        - Never share or imply sharing user data
        - If users express serious mental health concerns, gently suggest professional help
        - Maintain appropriate emotional boundaries while being supportive
        - Focus on journaling and reflection rather than problem-solving

        Remember: You're a companion for the journey of self-reflection, not a therapist. Your role is to help users explore their thoughts and feelings through writing.
        """
        
        try await ollamaService.createCompanionModel(systemPrompt: systemPrompt)
    }
    
    /// Check if the companion model exists
    func checkModelExists() async throws -> Bool {
        let health = try await ollamaService.checkHealth()
        return health // This checks if either gemma3n:latest or gemi-companion exists
    }
    
    /// Generate contextual prompts based on user's recent entries
    func generateReflectionPrompts(basedOn entries: [JournalEntry]) -> [String] {
        var prompts: [String] = []
        
        // Analyze recent moods
        let recentMoods = entries.prefix(7).compactMap { $0.mood }
        if !recentMoods.isEmpty {
            let moodCounts = Dictionary(grouping: recentMoods, by: { $0 }).mapValues { $0.count }
            if let dominantMood = moodCounts.max(by: { $0.value < $1.value })?.key {
                prompts.append("I noticed you've been feeling \(dominantMood.rawValue) lately. What do you think has been contributing to this?")
            }
        }
        
        // Check for patterns in tags
        let allTags = entries.flatMap { $0.tags }
        let tagCounts = Dictionary(grouping: allTags, by: { $0 }).mapValues { $0.count }
        if let frequentTag = tagCounts.max(by: { $0.value < $1.value })?.key {
            prompts.append("You've been writing about \(frequentTag) quite a bit. How do you feel about the progress you've made in this area?")
        }
        
        // Time-based prompts
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.component(.hour, from: now) < 10 {
            prompts.append("How would you like today to unfold? What intentions would you like to set?")
        } else if calendar.component(.hour, from: now) > 20 {
            prompts.append("As the day winds down, what are three things you're grateful for today?")
        }
        
        // Weekly reflection
        if calendar.component(.weekday, from: now) == 1 { // Sunday
            prompts.append("It's a new week ahead. What's one thing you'd like to focus on or achieve this week?")
        }
        
        // General prompts
        prompts.append(contentsOf: [
            "What's on your mind right now?",
            "Describe a moment from today that stood out to you.",
            "What emotions are you experiencing in this moment?",
            "If you could tell your past self one thing, what would it be?",
            "What's something you've been avoiding that you'd like to address?"
        ])
        
        return Array(prompts.shuffled().prefix(3))
    }
    
    /// Extract key memories from journal entries for AI context
    func extractMemories(from entries: [JournalEntry]) -> [MemoryData] {
        var memories: [MemoryData] = []
        
        for entry in entries {
            // Extract mood patterns
            if let mood = entry.mood {
                let moodMemory = MemoryData(
                    content: "On \(entry.createdAt.formatted(date: .abbreviated, time: .omitted)), felt \(mood)",
                    sourceEntryID: entry.id,
                    category: .emotional,
                    importance: 3
                )
                memories.append(moodMemory)
            }
            
            // Extract significant content (entries with high word count or multiple tags)
            let wordCount = entry.content.split(separator: " ").count
            if wordCount > 100 || entry.tags.count > 2 {
                let summary = extractSummary(from: entry.content)
                let contentMemory = MemoryData(
                    content: summary,
                    sourceEntryID: entry.id,
                    category: categorizeContent(entry.content),
                    importance: entry.isFavorite ? 5 : 4
                )
                memories.append(contentMemory)
            }
            
            // Extract entries with specific emotional keywords
            let emotionalKeywords = ["happy", "sad", "anxious", "excited", "worried", "grateful", "stressed", "peaceful"]
            let lowercasedContent = entry.content.lowercased()
            for keyword in emotionalKeywords {
                if lowercasedContent.contains(keyword) {
                    let emotionMemory = MemoryData(
                        content: "Expressed feeling \(keyword) about: \(extractContext(around: keyword, in: entry.content))",
                        sourceEntryID: entry.id,
                        category: .emotional,
                        importance: 4
                    )
                    memories.append(emotionMemory)
                    break
                }
            }
        }
        
        // Deduplicate and return top memories
        return Array(memories.sorted { $0.importance > $1.importance }.prefix(50))
    }
    
    private func extractSummary(from content: String) -> String {
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return sentences.prefix(2).joined(separator: ". ") + "."
    }
    
    private func categorizeContent(_ content: String) -> Memory.MemoryCategory {
        let lowercased = content.lowercased()
        
        if lowercased.contains("goal") || lowercased.contains("achieve") || lowercased.contains("plan") {
            return .goals
        } else if lowercased.contains("friend") || lowercased.contains("family") || lowercased.contains("partner") {
            return .relationships
        } else if lowercased.contains("accomplished") || lowercased.contains("succeeded") || lowercased.contains("proud") {
            return .achievements
        } else if lowercased.contains("challenge") || lowercased.contains("difficult") || lowercased.contains("struggle") {
            return .challenges
        } else {
            return .personal
        }
    }
    
    private func extractContext(around keyword: String, in content: String) -> String {
        let words = content.split(separator: " ")
        if let keywordIndex = words.firstIndex(where: { $0.lowercased().contains(keyword) }) {
            let startIndex = max(0, keywordIndex - 5)
            let endIndex = min(words.count, keywordIndex + 6)
            return words[startIndex..<endIndex].joined(separator: " ")
        }
        return ""
    }
}