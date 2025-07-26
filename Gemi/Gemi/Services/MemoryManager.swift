import Foundation
import OSLog

/// Manages AI memories extracted from journal entries
@MainActor
final class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    
    @Published var memories: [Memory] = []
    @Published var isProcessing = false
    
    private let companionService = CompanionModelService.shared
    private let databaseManager = DatabaseManager.shared
    private let logger = Logger(subsystem: "com.gemi.app", category: "MemoryManager")
    
    private init() {
        Task {
            await loadMemories()
        }
    }
    
    /// Load all memories from the database
    func loadMemories() async {
        do {
            // Load memories from database
            let dbMemories = try await loadMemoriesFromDatabase()
            
            // Update the in-memory array
            self.memories = dbMemories
            
            logger.info("Loaded \(self.memories.count) memories from database")
        } catch {
            logger.error("Failed to load memories from database: \(error)")
        }
    }
    
    /// Load memories from database
    private func loadMemoriesFromDatabase() async throws -> [Memory] {
        // Load from database
        let memoryDataArray = try await databaseManager.loadAllMemories()
        
        // Convert MemoryData to Memory objects using the initializer with ID
        return memoryDataArray.map { memoryData in
            Memory(
                id: memoryData.id,
                content: memoryData.content,
                sourceEntryID: memoryData.sourceEntryID,
                extractedAt: memoryData.extractedAt
            )
        }
    }
    
    /// Process journal entries to extract memories
    func processEntries(_ entries: [JournalEntry]) async {
        isProcessing = true
        defer { isProcessing = false }
        
        // Extract memories using the companion service
        let extractedMemoryData = await companionService.extractMemories(from: entries)
        
        // Remove existing memories for these entries to avoid duplicates
        let entryIDs = Set(entries.map { $0.id })
        memories.removeAll { entryIDs.contains($0.sourceEntryID) }
        
        // Add new memories
        for memoryData in extractedMemoryData {
            let memory = Memory(
                id: memoryData.id,
                content: memoryData.content,
                sourceEntryID: memoryData.sourceEntryID,
                extractedAt: memoryData.extractedAt
            )
            memories.append(memory)
            
            // Save to database
            Task {
                do {
                    try await databaseManager.saveMemory(memoryData)
                } catch {
                    logger.error("Failed to save memory to database: \(error)")
                }
            }
        }
        
        // Sort memories by date (most recent first)
        memories.sort { first, second in
            return first.extractedAt > second.extractedAt
        }
    }
    
    /// Get relevant memories for a conversation based on the current message
    func getRelevantMemories(for message: String, limit: Int = 10) -> [Memory] {
        // Simple relevance scoring based on keyword matching
        let keywords = extractKeywords(from: message)
        
        let scoredMemories = memories.map { memory -> (Memory, Int) in
            var score = 0
            
            // Check for keyword matches
            let memoryKeywords = extractKeywords(from: memory.content)
            let matchingKeywords = keywords.intersection(memoryKeywords)
            score += matchingKeywords.count * 2
            
            // Boost recent memories slightly
            let daysSinceExtracted = Calendar.current.dateComponents([.day], from: memory.extractedAt, to: Date()).day ?? 0
            if daysSinceExtracted < 7 {
                score += 2
            } else if daysSinceExtracted < 30 {
                score += 1
            }
            
            return (memory, score)
        }
        
        // Sort by score and return top memories
        return scoredMemories
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }
    
    /// Search memories (alias for getRelevantMemories for compatibility)
    func searchMemories(for message: String, limit: Int = 10) -> [Memory] {
        return getRelevantMemories(for: message, limit: limit)
    }
    
    /// Delete a specific memory
    func deleteMemory(_ memory: Memory) {
        memories.removeAll { $0.id == memory.id }
        
        // Delete from database using just the ID
        Task {
            do {
                try await databaseManager.deleteMemoryByID(memory.id)
                logger.info("Deleted memory from database: \(memory.id)")
            } catch {
                logger.error("Failed to delete memory from database: \(error)")
            }
        }
    }
    
    /// Clean markdown formatting from all existing memories
    func cleanMarkdownFromMemories() async {
        logger.info("Cleaning markdown from \(self.memories.count) memories")
        
        var cleanedCount = 0
        for memory in memories {
            let cleanedContent = memory.content
                .replacingOccurrences(of: "\\*\\*(.*?)\\*\\*", with: "$1", options: .regularExpression) // Remove **bold**
                .replacingOccurrences(of: "\\*(.*?)\\*", with: "$1", options: .regularExpression) // Remove *italic*
                .replacingOccurrences(of: "__(.*?)__", with: "$1", options: .regularExpression) // Remove __underline__
                .replacingOccurrences(of: "_(.*?)_", with: "$1", options: .regularExpression) // Remove _italic_
                .replacingOccurrences(of: "#+ ", with: "", options: .regularExpression) // Remove markdown headers
                .replacingOccurrences(of: "`(.*?)`", with: "$1", options: .regularExpression) // Remove `code`
            
            if cleanedContent != memory.content {
                memory.content = cleanedContent
                cleanedCount += 1
                logger.debug("Cleaned memory: \(memory.id)")
                
                // Save individual memory
                let memoryData = MemoryData(
                    id: memory.id,
                    content: memory.content,
                    sourceEntryID: memory.sourceEntryID,
                    extractedAt: memory.extractedAt
                )
                
                do {
                    try await databaseManager.saveMemory(memoryData)
                } catch {
                    logger.error("Failed to save cleaned memory: \(error)")
                }
            }
        }
        
        logger.info("Cleaned markdown from \(cleanedCount) memories")
    }
    
    /// Clear all memories (with user confirmation)
    func clearAllMemories() async {
        memories.removeAll()
        
        // Clear from database
        do {
            try await databaseManager.clearAllMemoriesFromDB()
            logger.info("Cleared all memories from database")
        } catch {
            logger.error("Failed to clear memories from database: \(error)")
        }
    }
    
    /// Get memory statistics
    func getStatistics() -> MemoryStatistics {
        MemoryStatistics(
            totalCount: memories.count,
            oldestMemory: memories.min(by: { $0.extractedAt < $1.extractedAt })?.extractedAt,
            newestMemory: memories.max(by: { $0.extractedAt < $1.extractedAt })?.extractedAt
        )
    }
    
    // MARK: - Private Helpers
    
    private func extractKeywords(from text: String) -> Set<String> {
        // Simple keyword extraction - in production, this could use NLP
        let stopWords: Set<String> = ["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "from", "is", "was", "are", "were", "been", "be", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "can", "this", "that", "these", "those", "i", "you", "he", "she", "it", "we", "they", "them", "their", "what", "which", "who", "when", "where", "why", "how", "all", "each", "every", "some", "any", "many", "most", "more", "other", "into", "through", "during", "before", "after", "above", "below", "up", "down", "out", "off", "over", "under", "again", "then", "than"]
        
        let words = text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 && !stopWords.contains($0) }
        
        return Set(words)
    }
}

// MARK: - Supporting Types

struct MemoryStatistics {
    let totalCount: Int
    let oldestMemory: Date?
    let newestMemory: Date?
}