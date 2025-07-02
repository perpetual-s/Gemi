//
//  JournalRAGService.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import Foundation
import os.log

@Observable
@MainActor
final class JournalRAGService {
    static let shared = JournalRAGService()
    
    private let logger = Logger(subsystem: "com.chaehoshin.Gemi", category: "JournalRAGService")
    private let embeddingService = EmbeddingService()
    private let contextRetriever = ContextRetriever()
    private let journalChunker = JournalChunker()
    
    // Background processing queue
    private let processingQueue = DispatchQueue(label: "com.chaehoshin.Gemi.JournalRAG", qos: .utility)
    
    private init() {
        startBackgroundProcessing()
    }
    
    // MARK: - Public Interface
    
    /// Retrieve relevant journal context for a given query
    func getRelevantContext(for query: String, limit: Int = 3) async throws -> String {
        logger.info("Getting relevant context for query: \(query.prefix(50))...")
        
        let results = try await contextRetriever.searchRelevantEntries(
            for: query,
            limit: limit
        )
        
        if results.entries.isEmpty {
            logger.info("No relevant entries found")
            return ""
        }
        
        let context = contextRetriever.assembleContext(from: results)
        logger.info("Assembled context with \(results.entries.count) entries")
        
        return context
    }
    
    /// Process a new journal entry for RAG
    func processNewEntry(_ entry: JournalEntry) async {
        logger.info("Processing new entry \(entry.id) for RAG")
        
        do {
            // Chunk the entry
            let chunkedEntry = journalChunker.splitEntry(entry)
            
            // Process each chunk
            for chunk in chunkedEntry.chunks {
                let contextualContent = journalChunker.preserveContext(
                    for: chunk,
                    from: chunkedEntry
                )
                
                // Generate embedding
                let embedding = try await embeddingService.generateEmbedding(
                    for: contextualContent
                )
                
                // Store embedding
                try await embeddingService.storeEmbedding(
                    entryId: entry.id,
                    text: contextualContent,
                    embedding: embedding
                )
            }
            
            logger.info("Successfully processed entry \(entry.id) with \(chunkedEntry.chunks.count) chunks")
        } catch {
            logger.error("Failed to process entry \(entry.id): \(error.localizedDescription)")
        }
    }
    
    /// Update embeddings for a modified entry
    func updateEntry(_ entry: JournalEntry) async {
        logger.info("Updating embeddings for modified entry \(entry.id)")
        
        do {
            // Delete old embeddings
            try await DatabaseManager.shared().deleteMemoriesForEntry(entry.id)
            
            // Process as new
            await processNewEntry(entry)
        } catch {
            logger.error("Failed to update entry \(entry.id): \(error.localizedDescription)")
        }
    }
    
    /// Search with advanced filters
    func searchWithFilters(
        query: String,
        dateRange: DateInterval? = nil,
        moods: [String]? = nil,
        tags: [String]? = nil,
        limit: Int = 5
    ) async throws -> String {
        let results = try await contextRetriever.searchWithFilters(
            query: query,
            dateRange: dateRange,
            moods: moods,
            tags: tags,
            limit: limit
        )
        
        return contextRetriever.assembleContext(from: results)
    }
    
    // MARK: - Chat Integration
    
    /// Enhance a chat message with relevant journal context
    func enhanceMessageWithContext(_ message: String) async throws -> String {
        // Don't add context for very short messages
        guard message.count > 20 else { return message }
        
        // Get relevant context
        let context = try await getRelevantContext(for: message, limit: 2)
        
        if context.isEmpty {
            return message
        }
        
        // Prepend context to the message
        return """
        \(context)
        
        Current question: \(message)
        """
    }
    
    // MARK: - Background Processing
    
    private func startBackgroundProcessing() {
        // Process unembedded entries on startup
        Task {
            try? await processUnembeddedEntries()
        }
        
        // Schedule periodic cleanup
        schedulePeriodicCleanup()
    }
    
    private func processUnembeddedEntries() async throws {
        logger.info("Starting background processing of unembedded entries")
        try await embeddingService.batchProcessEntries()
    }
    
    private func schedulePeriodicCleanup() {
        processingQueue.async {
            // Run cleanup every 24 hours
            Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
                Task {
                    try? await self.embeddingService.cleanupOrphanedEmbeddings()
                }
            }
        }
    }
    
    // MARK: - Utility Functions
    
    /// Check if RAG is ready (model available, entries processed)
    func checkReadiness() async -> (isReady: Bool, message: String) {
        do {
            // Check if embedding model is available
            let ollamaService = OllamaService.shared
            let models = try await ollamaService.listModels()
            
            guard models.contains(where: { $0.contains("nomic-embed-text") }) else {
                return (false, "Embedding model not found. Please install nomic-embed-text.")
            }
            
            // Check if we have any processed entries
            let memoryCount = try await DatabaseManager.shared().getMemoryCount()
            if memoryCount == 0 {
                // Try to process entries
                try await processUnembeddedEntries()
                return (true, "Processing journal entries for the first time...")
            }
            
            return (true, "RAG system ready with \(memoryCount) indexed memories")
        } catch {
            return (false, "RAG system error: \(error.localizedDescription)")
        }
    }
    
    /// Get statistics about the RAG system
    func getStatistics() async throws -> RAGStatistics {
        let memoryCount = try await DatabaseManager.shared().getMemoryCount()
        let entryCount = try await DatabaseManager.shared().getEntryCount()
        let processedCount = try await DatabaseManager.shared().getEntriesWithEmbeddingsCount()
        
        return RAGStatistics(
            totalEntries: entryCount,
            processedEntries: processedCount,
            totalMemories: memoryCount,
            averageMemoriesPerEntry: entryCount > 0 ? Float(memoryCount) / Float(entryCount) : 0
        )
    }
    
    struct RAGStatistics {
        let totalEntries: Int
        let processedEntries: Int
        let totalMemories: Int
        let averageMemoriesPerEntry: Float
    }
}

