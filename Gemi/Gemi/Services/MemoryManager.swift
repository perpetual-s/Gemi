import Foundation
import SwiftData

/// Manages AI memories extracted from journal entries
@MainActor
final class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    
    @Published var memories: [Memory] = []
    @Published var isProcessing = false
    
    private let companionService = CompanionModelService.shared
    private let databaseManager = DatabaseManager.shared
    private var modelContext: ModelContext?
    
    private init() {}
    
    /// Initialize the memory manager with a model context
    func initialize(with context: ModelContext) {
        self.modelContext = context
        Task {
            await loadMemories()
        }
    }
    
    /// Load all memories from the database
    func loadMemories() async {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<Memory>(
                sortBy: [SortDescriptor(\.importance, order: .reverse),
                        SortDescriptor(\.extractedAt, order: .reverse)]
            )
            memories = try context.fetch(descriptor)
        } catch {
            print("Failed to load memories: \(error)")
        }
    }
    
    /// Process journal entries to extract memories
    func processEntries(_ entries: [JournalEntry]) async {
        guard let context = modelContext else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Extract memories using the companion service
        let extractedMemoryData = await companionService.extractMemories(from: entries)
        
        // Remove existing memories for these entries to avoid duplicates
        let entryIDs = Set(entries.map { $0.id })
        let existingMemories = memories.filter { entryIDs.contains($0.sourceEntryID) }
        
        for memory in existingMemories {
            context.delete(memory)
        }
        
        // Add new memories
        for memoryData in extractedMemoryData {
            let memory = Memory(
                content: memoryData.content,
                sourceEntryID: memoryData.sourceEntryID,
                category: memoryData.category,
                importance: memoryData.importance
            )
            context.insert(memory)
        }
        
        // Save changes
        do {
            try context.save()
            await loadMemories()
        } catch {
            print("Failed to save memories: \(error)")
        }
    }
    
    /// Get relevant memories for a conversation based on the current message
    func getRelevantMemories(for message: String, limit: Int = 10) -> [Memory] {
        // Simple relevance scoring based on keyword matching
        let keywords = extractKeywords(from: message)
        
        let scoredMemories = memories.map { memory -> (Memory, Int) in
            var score = memory.importance
            
            // Check for keyword matches
            let memoryKeywords = extractKeywords(from: memory.content)
            let matchingKeywords = keywords.intersection(memoryKeywords)
            score += matchingKeywords.count * 2
            
            // Boost recent memories slightly
            let daysSinceExtracted = Calendar.current.dateComponents([.day], from: memory.extractedAt, to: Date()).day ?? 0
            if daysSinceExtracted < 7 {
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
    
    /// Delete a specific memory
    func deleteMemory(_ memory: Memory) {
        guard let context = modelContext else { return }
        
        context.delete(memory)
        
        do {
            try context.save()
            memories.removeAll { $0.id == memory.id }
        } catch {
            print("Failed to delete memory: \(error)")
        }
    }
    
    /// Update memory importance
    func updateImportance(for memory: Memory, importance: Int) {
        memory.importance = min(max(importance, 1), 5)
        
        guard let context = modelContext else { return }
        
        do {
            try context.save()
        } catch {
            print("Failed to update memory importance: \(error)")
        }
    }
    
    /// Clear all memories (with user confirmation)
    func clearAllMemories() async {
        guard let context = modelContext else { return }
        
        for memory in memories {
            context.delete(memory)
        }
        
        do {
            try context.save()
            memories.removeAll()
        } catch {
            print("Failed to clear memories: \(error)")
        }
    }
    
    /// Get memories grouped by category
    func memoriesByCategory() -> [Memory.MemoryCategory: [Memory]] {
        Dictionary(grouping: memories, by: { $0.category })
    }
    
    /// Get memory statistics
    func getStatistics() -> MemoryStatistics {
        MemoryStatistics(
            totalCount: memories.count,
            categoryCounts: Dictionary(grouping: memories, by: { $0.category }).mapValues { $0.count },
            averageImportance: memories.isEmpty ? 0 : Double(memories.reduce(0) { $0 + $1.importance }) / Double(memories.count),
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
    let categoryCounts: [Memory.MemoryCategory: Int]
    let averageImportance: Double
    let oldestMemory: Date?
    let newestMemory: Date?
}

// MARK: - Memory View Model for UI

@MainActor
final class MemoryViewModel: ObservableObject {
    @Published var selectedCategory: Memory.MemoryCategory?
    @Published var searchText = ""
    @Published var sortOrder: SortOrder = .byImportance
    @Published var showOnlyHighImportance = false
    
    private let memoryManager = MemoryManager.shared
    
    enum SortOrder: String, CaseIterable {
        case byImportance = "Importance"
        case byDate = "Date"
        case byCategory = "Category"
    }
    
    var filteredMemories: [Memory] {
        var filtered = memoryManager.memories
        
        // Filter by category
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.content.localizedCaseInsensitiveContains(searchText) 
            }
        }
        
        // Filter by importance
        if showOnlyHighImportance {
            filtered = filtered.filter { $0.importance >= 4 }
        }
        
        // Sort
        switch sortOrder {
        case .byImportance:
            filtered.sort { $0.importance > $1.importance }
        case .byDate:
            filtered.sort { $0.extractedAt > $1.extractedAt }
        case .byCategory:
            filtered.sort { $0.category.rawValue < $1.category.rawValue }
        }
        
        return filtered
    }
    
    func deleteMemory(_ memory: Memory) {
        memoryManager.deleteMemory(memory)
    }
    
    func updateImportance(for memory: Memory, importance: Int) {
        memoryManager.updateImportance(for: memory, importance: importance)
    }
}