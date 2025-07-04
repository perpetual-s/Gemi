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
    
    static let shared = MemoryStore()
    
    // MARK: - Properties
    
    private let databaseManager: DatabaseManager
    private let logger = Logger(subsystem: "com.gemi.app", category: "MemoryStore")
    
    /// Cache for frequently accessed memories
    private var memoryCache: [UUID: Memory] = [:]
    
    /// User defaults keys
    static let defaultMemoryLimit = 1000
    static let memoryLimitKey = "memoryLimit"
    static let archiveDirectoryName = "MemoryArchives"
    
    /// Maximum number of memories to keep (older, less important ones are archived)
    var memoryLimit: Int {
        UserDefaults.standard.integer(forKey: Self.memoryLimitKey) != 0 ? 
        UserDefaults.standard.integer(forKey: Self.memoryLimitKey) : Self.defaultMemoryLimit
    }
    
    /// Minimum importance threshold for keeping memories
    private let minImportanceThreshold: Float = 0.1
    
    /// Archive directory URL
    private var archiveDirectoryURL: URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documentsURL.appendingPathComponent(Self.archiveDirectoryName)
    }
    
    // MARK: - Initialization
    
    private init() {
        do {
            self.databaseManager = try DatabaseManager.shared()
        } catch {
            // Log the error but don't crash - memory features will fail gracefully
            logger.error("Failed to initialize DatabaseManager: \(error)")
            // Re-throw to let callers handle it
            // Since this is an actor init, we can't throw, so we'll store nil
            // and check in each method
            self.databaseManager = try! DatabaseManager.shared() // This will crash with better context
        }
    }
    
    // MARK: - Public Methods
    
    /// Add a memory directly
    func addMemory(_ memory: Memory) async throws {
        logger.info("Adding memory: \(memory.id)")
        try await saveMemory(memory)
        try await archiveMemoriesIfNeeded()
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
        
        // Archive old memories if needed
        try await archiveMemoriesIfNeeded()
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
        
        // Archive old memories if needed
        try await archiveMemoriesIfNeeded()
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
    
    @MainActor
    private func generateEmbedding(for text: String) async throws -> [Double] {
        return try await OllamaService.shared.generateEmbedding(for: text)
    }
    
    @MainActor
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
            for try await chunk in OllamaService.shared.chatCompletion(prompt: prompt) {
                extractedContent += chunk
            }
        } catch {
            logger.error("Failed to extract memory content: \(error)")
            return ""
        }
        
        return extractedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    @MainActor
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
            for try await chunk in OllamaService.shared.chatCompletion(prompt: prompt) {
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
    
    /// Check if memory archival is needed
    func shouldArchiveMemories() async throws -> Bool {
        let count = try await databaseManager.getMemoryCount()
        return count > memoryLimit
    }
    
    /// Get archive statistics
    func getArchiveStats() async throws -> ArchiveStats {
        guard let archiveDir = archiveDirectoryURL else {
            return ArchiveStats(totalArchives: 0, totalArchivedMemories: 0, oldestArchive: nil, newestArchive: nil)
        }
        
        let fileManager = FileManager.default
        
        // Create archive directory if it doesn't exist
        if !fileManager.fileExists(atPath: archiveDir.path) {
            try fileManager.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        }
        
        let archiveFiles = try fileManager.contentsOfDirectory(at: archiveDir, includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.pathExtension == "json" }
        
        var totalMemories = 0
        var oldestDate: Date?
        var newestDate: Date?
        
        for file in archiveFiles {
            if let data = try? Data(contentsOf: file),
               let memories = try? JSONDecoder().decode([Memory].self, from: data) {
                totalMemories += memories.count
            }
            
            if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate {
                if oldestDate == nil || creationDate < oldestDate! {
                    oldestDate = creationDate
                }
                if newestDate == nil || creationDate > newestDate! {
                    newestDate = creationDate
                }
            }
        }
        
        return ArchiveStats(
            totalArchives: archiveFiles.count,
            totalArchivedMemories: totalMemories,
            oldestArchive: oldestDate,
            newestArchive: newestDate
        )
    }
    
    /// Export all memories to a file
    func exportMemories(includeArchived: Bool = false) async throws -> URL {
        // Fetch all current memories
        let currentMemories = try await databaseManager.database.read { db in
            try Memory.fetchAll(db)
        }
        
        var allMemories = currentMemories
        
        // Include archived memories if requested
        if includeArchived, let archiveDir = archiveDirectoryURL {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: archiveDir.path) {
                let archiveFiles = try fileManager.contentsOfDirectory(at: archiveDir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "json" }
                
                for file in archiveFiles {
                    if let data = try? Data(contentsOf: file),
                       let archivedMemories = try? JSONDecoder().decode([Memory].self, from: data) {
                        allMemories.append(contentsOf: archivedMemories)
                    }
                }
            }
        }
        
        // Create export data
        let exportData = MemoryExport(
            exportDate: Date(),
            totalMemories: allMemories.count,
            memories: allMemories
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        
        // Save to file
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gemi_memories_export_\(Date().timeIntervalSince1970).json")
        try data.write(to: exportURL)
        
        logger.info("Exported \(allMemories.count) memories to \(exportURL.path)")
        return exportURL
    }
    
    /// Archive old memories instead of deleting them
    private func archiveMemoriesIfNeeded() async throws {
        let count = try await databaseManager.database.read { db in
            try Memory.fetchCount(db)
        }
        
        guard count > self.memoryLimit else { return }
        
        logger.info("Archiving memories: \(count) > \(self.memoryLimit)")
        
        // Get memories to archive (oldest, least important, not pinned)
        let memoriesToArchive = try await databaseManager.database.read { db in
            try Memory
                .filter(Memory.Columns.isPinned == false)
                .order(
                    Memory.Columns.importance,
                    Memory.Columns.lastAccessedAt
                )
                .limit(count - self.memoryLimit)
                .fetchAll(db)
        }
        
        // Archive them
        try await archiveMemories(memoriesToArchive)
        
        // Delete from active storage
        _ = try await databaseManager.database.write { db in
            for memory in memoriesToArchive {
                try memory.delete(db)
            }
        }
        
        // Remove from cache
        for memory in memoriesToArchive {
            memoryCache.removeValue(forKey: memory.id)
        }
        
        logger.info("Archived \(memoriesToArchive.count) memories")
    }
    
    /// Archive memories to a JSON file
    private func archiveMemories(_ memories: [Memory]) async throws {
        guard !memories.isEmpty else { return }
        guard let archiveDir = archiveDirectoryURL else {
            throw MemoryArchiveError.unableToCreateArchiveDirectory
        }
        
        let fileManager = FileManager.default
        
        // Create archive directory if it doesn't exist
        if !fileManager.fileExists(atPath: archiveDir.path) {
            try fileManager.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        }
        
        // Create archive file
        let archiveData = try JSONEncoder().encode(memories)
        let timestamp = Date().timeIntervalSince1970
        let archiveURL = archiveDir.appendingPathComponent("memory_archive_\(timestamp).json")
        
        try archiveData.write(to: archiveURL)
        logger.info("Archived \(memories.count) memories to \(archiveURL.lastPathComponent)")
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

// MARK: - Archive Statistics

struct ArchiveStats {
    let totalArchives: Int
    let totalArchivedMemories: Int
    let oldestArchive: Date?
    let newestArchive: Date?
}

// MARK: - Memory Export

struct MemoryExport: Codable {
    let exportDate: Date
    let totalMemories: Int
    let memories: [Memory]
}

// MARK: - Memory Archive Error

enum MemoryArchiveError: Error, LocalizedError {
    case unableToCreateArchiveDirectory
    case archiveDecodingFailed
    case exportFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unableToCreateArchiveDirectory:
            return "Unable to create memory archive directory"
        case .archiveDecodingFailed:
            return "Failed to decode archived memories"
        case .exportFailed(let reason):
            return "Failed to export memories: \(reason)"
        }
    }
}