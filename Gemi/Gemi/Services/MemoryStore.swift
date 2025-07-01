//
//  MemoryStore.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import Foundation
import GRDB
import os.log

/// Thread-safe actor for managing memories with vector search capabilities
actor MemoryStore {
    
    // MARK: - Singleton
    
    static let shared = MemoryStore(
        databaseManager: DatabaseManager.shared,
        ollamaService: OllamaService.shared
    )
    
    // MARK: - Properties
    
    private let databaseManager: DatabaseManager
    nonisolated private let ollamaService: OllamaService
    private let logger = Logger(subsystem: "com.gemi.app", category: "MemoryStore")
    
    /// Cache for frequently accessed memories
    private var memoryCache: [UUID: Memory] = [:]
    
    /// Maximum number of memories to keep (older, less important ones are pruned)
    private let maxMemoryCount = 1000
    
    /// Minimum importance threshold for keeping memories
    private let minImportanceThreshold: Float = 0.1
    
    // MARK: - Initialization
    
    init(databaseManager: DatabaseManager, ollamaService: OllamaService) {
        self.databaseManager = databaseManager
        self.ollamaService = ollamaService
    }
    
    // MARK: - Public Methods
    
    /// Add a memory directly
    func addMemory(_ memory: Memory) async throws {
        logger.info("Adding memory: \(memory.id)")
        try await saveMemory(memory)
        try await pruneMemoriesIfNeeded()
    }
    
    /// Add a new memory from a conversation
    func addMemoryFromConversation(userMessage: String, aiResponse: String) async throws {
        logger.info("Adding memory from conversation")
        
        // Extract key information from the conversation
        let memoryContent = await extractMemoryContent(from: userMessage, response: aiResponse)
        guard !memoryContent.isEmpty else { return }
        
        // Generate embedding
        let embedding = try await generateEmbedding(for: memoryContent)
        
        // Calculate importance based on content
        let importance = calculateImportance(for: memoryContent, userMessage: userMessage)
        
        // Extract tags
        let tags = extractTags(from: memoryContent)
        
        // Create memory
        let memory = Memory(
            content: memoryContent,
            embedding: Memory.embeddingToData(embedding),
            importance: importance,
            tags: tags,
            memoryType: .conversation
        )
        
        // Save to database
        try await saveMemory(memory)
        
        // Prune old memories if needed
        try await pruneMemoriesIfNeeded()
    }
    
    /// Add a new memory from a journal entry
    func addMemoryFromJournalEntry(_ entry: JournalEntry) async throws {
        logger.info("Extracting memories from journal entry")
        
        // Extract key facts from the entry
        let facts = await extractFactsFromEntry(entry)
        
        for fact in facts {
            // Generate embedding
            let embedding = try await generateEmbedding(for: fact.content)
            
            // Create memory
            let memory = Memory(
                content: fact.content,
                embedding: Memory.embeddingToData(embedding),
                sourceEntryId: entry.id,
                importance: fact.importance,
                tags: fact.tags,
                memoryType: .journalFact
            )
            
            // Save to database
            try await saveMemory(memory)
        }
        
        // Prune old memories if needed
        try await pruneMemoriesIfNeeded()
    }
    
    /// Search memories using vector similarity
    func searchMemories(query: String, limit: Int = 10) async throws -> [Memory] {
        logger.info("Searching memories for query: \(query)")
        
        // Generate embedding for query
        let queryEmbedding = try await generateEmbedding(for: query)
        
        // Fetch all memories with embeddings
        let memories = try await databaseManager.database.read { db in
            try Memory
                .filter(Memory.Columns.embedding != nil)
                .fetchAll(db)
        }
        
        // Calculate similarities and sort
        let rankedMemories = memories.compactMap { memory -> (Memory, Double)? in
            guard let memoryEmbedding = memory.getEmbeddingVector() else { return nil }
            let similarity = Memory.cosineSimilarity(queryEmbedding, memoryEmbedding)
            return (memory, similarity)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(limit)
        .map { $0.0 }
        
        // Update last accessed time for returned memories
        for memory in rankedMemories {
            try await updateLastAccessed(memory.id)
        }
        
        return Array(rankedMemories)
    }
    
    /// Get memories related to a specific journal entry
    func getMemoriesForContext(entryId: UUID? = nil, limit: Int = 5) async throws -> [Memory] {
        logger.info("Getting context memories")
        
        return try await databaseManager.database.read { db in
            var query = Memory.all()
            
            // If entry ID provided, prioritize memories from that entry
            if let entryId = entryId {
                query = query
                    .filter(Memory.Columns.sourceEntryId == entryId.uuidString)
                    .limit(limit)
            } else {
                // Get most recent and important memories
                query = query
                    .order(
                        Memory.Columns.isPinned.desc,
                        Memory.Columns.importance.desc,
                        Memory.Columns.lastAccessedAt.desc
                    )
                    .limit(limit)
            }
            
            return try query.fetchAll(db)
        }
    }
    
    /// Delete a specific memory
    func deleteMemory(id: UUID) async throws {
        logger.info("Deleting memory: \(id)")
        
        _ = try await databaseManager.database.write { db in
            try Memory.deleteOne(db, key: id)
        }
        
        // Remove from cache
        memoryCache.removeValue(forKey: id)
    }
    
    /// Clear all memories (with optional type filter)
    func clearAllMemories(ofType type: MemoryType? = nil) async throws {
        logger.info("Clearing memories of type: \(type?.rawValue ?? "all")")
        
        _ = try await databaseManager.database.write { db in
            if let type = type {
                try Memory
                    .filter(Memory.Columns.memoryType == type.rawValue)
                    .deleteAll(db)
            } else {
                try Memory.deleteAll(db)
            }
        }
        
        // Clear cache
        if type == nil {
            memoryCache.removeAll()
        } else {
            memoryCache = memoryCache.filter { $0.value.memoryType != type }
        }
    }
    
    /// Get all memories (with pagination)
    func getAllMemories(offset: Int = 0, limit: Int = 50) async throws -> [Memory] {
        logger.info("Fetching all memories")
        
        return try await databaseManager.database.read { db in
            try Memory
                .order(
                    Memory.Columns.isPinned.desc,
                    Memory.Columns.createdAt.desc
                )
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }
    
    /// Update memory importance
    func updateMemoryImportance(id: UUID, importance: Float) async throws {
        logger.info("Updating memory importance")
        
        let updatedMemory = try await databaseManager.database.write { db -> Memory? in
            if var memory = try Memory.fetchOne(db, key: id) {
                memory.importance = importance
                try memory.save(db)
                return memory
            }
            return nil
        }
        
        // Update cache
        if let memory = updatedMemory {
            memoryCache[id] = memory
        }
    }
    
    /// Pin/unpin a memory
    func toggleMemoryPin(id: UUID) async throws {
        logger.info("Toggling memory pin")
        
        let updatedMemory = try await databaseManager.database.write { db -> Memory? in
            if var memory = try Memory.fetchOne(db, key: id) {
                memory.isPinned.toggle()
                try memory.save(db)
                return memory
            }
            return nil
        }
        
        // Update cache
        if let memory = updatedMemory {
            memoryCache[id] = memory
        }
    }
    
    /// Get memory statistics
    func getMemoryStats() async throws -> MemoryStats {
        logger.info("Getting memory statistics")
        
        return try await databaseManager.database.read { db in
            let totalCount = try Memory.fetchCount(db)
            let pinnedCount = try Memory.filter(Memory.Columns.isPinned == true).fetchCount(db)
            
            let typeCounts = try MemoryType.allCases.reduce(into: [:]) { result, type in
                result[type] = try Memory
                    .filter(Memory.Columns.memoryType == type.rawValue)
                    .fetchCount(db)
            }
            
            let oldestMemory = try Memory
                .order(Memory.Columns.createdAt)
                .fetchOne(db)
            
            let newestMemory = try Memory
                .order(Memory.Columns.createdAt.desc)
                .fetchOne(db)
            
            return MemoryStats(
                totalCount: totalCount,
                pinnedCount: pinnedCount,
                typeCounts: typeCounts,
                oldestMemoryDate: oldestMemory?.createdAt,
                newestMemoryDate: newestMemory?.createdAt
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func saveMemory(_ memory: Memory) async throws {
        _ = try await databaseManager.database.write { db in
            try memory.save(db)
        }
        
        // Add to cache
        memoryCache[memory.id] = memory
        
        logger.info("Saved memory: \(memory.id)")
    }
    
    private func updateLastAccessed(_ id: UUID) async throws {
        let updatedMemory = try await databaseManager.database.write { db -> Memory? in
            if var memory = try Memory.fetchOne(db, key: id) {
                memory.lastAccessedAt = Date()
                try memory.save(db)
                return memory
            }
            return nil
        }
        
        // Update cache
        if let memory = updatedMemory {
            memoryCache[id] = memory
        }
    }
    
    private func generateEmbedding(for text: String) async throws -> [Double] {
        return try await ollamaService.generateEmbedding(for: text)
    }
    
    private func extractMemoryContent(from userMessage: String, response aiResponse: String) async -> String {
        // Use AI to extract key information
        let prompt = """
        Extract the most important fact or information from this conversation that should be remembered.
        Keep it concise (1-2 sentences) and in third person.
        If there's nothing worth remembering, return empty string.
        
        User: \(userMessage)
        Assistant: \(aiResponse)
        
        Important fact to remember:
        """
        
        var extractedContent = ""
        
        do {
            for try await chunk in await ollamaService.chatCompletion(prompt: prompt) {
                extractedContent += chunk
            }
        } catch {
            logger.error("Failed to extract memory content: \(error)")
            return ""
        }
        
        return extractedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractFactsFromEntry(_ entry: JournalEntry) async -> [(content: String, importance: Float, tags: [String])] {
        let prompt = """
        Extract important facts from this journal entry. Return each fact on a new line.
        Focus on: people mentioned, events, feelings, decisions, places.
        Keep each fact concise (1 sentence).
        Format: FACT: <content> | IMPORTANCE: <0.0-1.0> | TAGS: <comma,separated,tags>
        
        Journal entry:
        \(entry.content)
        
        Facts:
        """
        
        var facts: [(content: String, importance: Float, tags: [String])] = []
        var response = ""
        
        do {
            for try await chunk in await ollamaService.chatCompletion(prompt: prompt) {
                response += chunk
            }
            
            // Parse response
            let lines = response.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("FACT:") {
                    let components = line.components(separatedBy: "|")
                    if components.count >= 3 {
                        let fact = components[0].replacingOccurrences(of: "FACT:", with: "").trimmingCharacters(in: .whitespaces)
                        let importance = Float(components[1].replacingOccurrences(of: "IMPORTANCE:", with: "").trimmingCharacters(in: .whitespaces)) ?? 0.5
                        let tags = components[2].replacingOccurrences(of: "TAGS:", with: "").trimmingCharacters(in: .whitespaces).components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        
                        facts.append((content: fact, importance: importance, tags: tags))
                    }
                }
            }
        } catch {
            logger.error("Failed to extract facts from entry: \(error)")
        }
        
        return facts
    }
    
    private func calculateImportance(for content: String, userMessage: String) -> Float {
        // Simple heuristic for importance
        var importance: Float = 0.5
        
        // Increase importance for certain keywords
        let importantKeywords = ["important", "remember", "never forget", "always", "love", "hate", "milestone", "achieved", "decided"]
        let lowerContent = content.lowercased()
        let lowerMessage = userMessage.lowercased()
        
        for keyword in importantKeywords {
            if lowerContent.contains(keyword) || lowerMessage.contains(keyword) {
                importance += 0.1
            }
        }
        
        // Cap at 1.0
        return min(importance, 1.0)
    }
    
    private func extractTags(from content: String) -> [String] {
        var tags: [String] = []
        
        // Extract people (simple heuristic - words starting with capital)
        let words = content.components(separatedBy: .whitespaces)
        for word in words {
            if let first = word.first, first.isUppercase && word.count > 2 {
                let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
                if !cleaned.isEmpty && !commonWords.contains(cleaned.lowercased()) {
                    tags.append(cleaned)
                }
            }
        }
        
        // Add emotion tags
        let emotions = ["happy", "sad", "angry", "excited", "worried", "grateful", "anxious"]
        let lowerContent = content.lowercased()
        for emotion in emotions {
            if lowerContent.contains(emotion) {
                tags.append(emotion)
            }
        }
        
        return Array(Set(tags)) // Remove duplicates
    }
    
    private let commonWords = Set(["the", "and", "but", "for", "with", "this", "that", "these", "those", "today", "yesterday", "tomorrow"])
    
    private func pruneMemoriesIfNeeded() async throws {
        let count = try await databaseManager.database.read { db in
            try Memory.fetchCount(db)
        }
        
        guard count > self.maxMemoryCount else { return }
        
        logger.info("Pruning memories: \(count) > \(self.maxMemoryCount)")
        
        // Get memories to prune (oldest, least important, not pinned)
        let memoriesToDelete = try await databaseManager.database.read { db in
            try Memory
                .filter(Memory.Columns.isPinned == false)
                .order(
                    Memory.Columns.importance,
                    Memory.Columns.lastAccessedAt
                )
                .limit(count - self.maxMemoryCount)
                .fetchAll(db)
        }
        
        // Delete them
        _ = try await databaseManager.database.write { db in
            for memory in memoriesToDelete {
                try memory.delete(db)
            }
        }
        
        // Remove from cache
        for memory in memoriesToDelete {
            memoryCache.removeValue(forKey: memory.id)
        }
        
        logger.info("Pruned \(memoriesToDelete.count) memories")
    }
}

// MARK: - Memory Statistics

struct MemoryStats {
    let totalCount: Int
    let pinnedCount: Int
    let typeCounts: [MemoryType: Int]
    let oldestMemoryDate: Date?
    let newestMemoryDate: Date?
    
    var averageMemoriesPerDay: Double {
        guard let oldest = oldestMemoryDate,
              let newest = newestMemoryDate,
              totalCount > 0 else { return 0 }
        
        let days = Calendar.current.dateComponents([.day], from: oldest, to: newest).day ?? 1
        return Double(totalCount) / Double(max(days, 1))
    }
}