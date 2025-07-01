//
//  ContextRetriever.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import Foundation
import os.log

@Observable
@MainActor
final class ContextRetriever {
    private let logger = Logger(subsystem: "com.chaehoshin.Gemi", category: "ContextRetriever")
    private let embeddingService = EmbeddingService()
    private let databaseManager = DatabaseManager.shared
    
    // Configuration
    private let defaultResultLimit = 5
    private let maxContextLength = 4000 // Leave room for user query and system prompt
    private let recencyBoost = 0.2 // How much to boost recent entries
    
    struct RetrievalResult {
        var entries: [RelevantEntry]
        let totalRelevanceScore: Float
    }
    
    struct RelevantEntry {
        let memory: Memory
        let relevanceScore: Float
        let temporalScore: Float
        let finalScore: Float
        let sourceEntry: JournalEntry?
    }
    
    // MARK: - Search Functions
    
    func searchRelevantEntries(for query: String, limit: Int? = nil) async throws -> RetrievalResult {
        logger.info("Searching for relevant entries for query: \(query.prefix(50))...")
        
        let resultLimit = limit ?? defaultResultLimit
        
        // Generate embedding for the query
        let queryEmbedding = try await embeddingService.generateEmbedding(for: query)
        
        // Search for similar memories
        let memories = try await databaseManager.searchMemoriesBySimilarity(
            embedding: queryEmbedding,
            limit: resultLimit * 2 // Get more to apply temporal filtering
        )
        
        // Calculate relevance with temporal weighting
        var relevantEntries: [RelevantEntry] = []
        for memory in memories {
            let relevanceScore = calculateCosineSimilarity(
                queryEmbedding: queryEmbedding,
                memoryEmbedding: memory.embedding
            )
            
            let temporalScore = calculateTemporalScore(for: memory)
            let finalScore = combineScores(relevance: relevanceScore, temporal: temporalScore)
            
            // Try to fetch the source journal entry
            let sourceEntry = memory.sourceEntryId != nil 
                ? try? await databaseManager.fetchEntry(by: memory.sourceEntryId!)
                : nil
            
            relevantEntries.append(RelevantEntry(
                memory: memory,
                relevanceScore: relevanceScore,
                temporalScore: temporalScore,
                finalScore: finalScore,
                sourceEntry: sourceEntry
            ))
        }
        
        // Sort by final score and take top results
        relevantEntries.sort { $0.finalScore > $1.finalScore }
        let topEntries = Array(relevantEntries.prefix(resultLimit))
        
        let totalScore = topEntries.reduce(0) { $0 + $1.finalScore }
        
        logger.info("Found \(topEntries.count) relevant entries with total score: \(totalScore)")
        
        return RetrievalResult(entries: topEntries, totalRelevanceScore: totalScore)
    }
    
    // MARK: - Scoring Functions
    
    private func calculateCosineSimilarity(queryEmbedding: [Float], memoryEmbedding: Data?) -> Float {
        guard let embeddingData = memoryEmbedding else { return 0.0 }
        
        // Convert Data back to [Float]
        let memoryVector = embeddingData.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float.self))
        }
        
        guard queryEmbedding.count == memoryVector.count else {
            logger.warning("Embedding dimension mismatch")
            return 0.0
        }
        
        // Calculate cosine similarity
        var dotProduct: Float = 0
        var queryMagnitude: Float = 0
        var memoryMagnitude: Float = 0
        
        for i in 0..<queryEmbedding.count {
            dotProduct += queryEmbedding[i] * memoryVector[i]
            queryMagnitude += queryEmbedding[i] * queryEmbedding[i]
            memoryMagnitude += memoryVector[i] * memoryVector[i]
        }
        
        queryMagnitude = sqrt(queryMagnitude)
        memoryMagnitude = sqrt(memoryMagnitude)
        
        guard queryMagnitude > 0 && memoryMagnitude > 0 else { return 0.0 }
        
        return dotProduct / (queryMagnitude * memoryMagnitude)
    }
    
    private func calculateTemporalScore(for memory: Memory) -> Float {
        let now = Date()
        let daysSinceCreation = Calendar.current.dateComponents(
            [.day], 
            from: memory.createdAt, 
            to: now
        ).day ?? 0
        
        // Exponential decay: newer entries get higher scores
        // Score approaches 0 as days increase
        let decayRate: Float = 0.05
        let temporalScore = exp(-decayRate * Float(daysSinceCreation))
        
        // Boost if recently accessed
        let daysSinceAccess = Calendar.current.dateComponents(
            [.day], 
            from: memory.lastAccessedAt, 
            to: now
        ).day ?? 0
        
        let accessBoost = daysSinceAccess < 7 ? 0.1 : 0.0
        
        return min(temporalScore + Float(accessBoost), 1.0)
    }
    
    private func combineScores(relevance: Float, temporal: Float) -> Float {
        // Weighted combination of relevance and temporal scores
        let relevanceWeight: Float = 0.8
        let temporalWeight: Float = 0.2
        
        return (relevance * relevanceWeight) + (temporal * temporalWeight)
    }
    
    // MARK: - Context Assembly
    
    func assembleContext(from results: RetrievalResult, maxLength: Int? = nil) -> String {
        let contextLimit = maxLength ?? maxContextLength
        var context = ""
        var currentLength = 0
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        for (_, entry) in results.entries.enumerated() {
            var entryContext = ""
            
            // Format entry header
            let date = entry.sourceEntry?.createdAt ?? entry.memory.createdAt
            entryContext += "--- Journal Entry from \(dateFormatter.string(from: date)) ---\n"
            
            // Add mood if available
            if let mood = entry.sourceEntry?.mood {
                entryContext += "Mood: \(mood)\n"
            }
            
            // Add relevance info for debugging (can be removed in production)
            entryContext += "Relevance: \(String(format: "%.2f", entry.finalScore))\n\n"
            
            // Add content
            if let sourceEntry = entry.sourceEntry {
                // Use full entry content if available
                entryContext += sourceEntry.content
            } else {
                // Fall back to memory content
                entryContext += entry.memory.content
            }
            
            entryContext += "\n\n"
            
            // Check if adding this entry would exceed the limit
            if currentLength + entryContext.count > contextLimit {
                // Try to add a truncated version
                let remainingSpace = contextLimit - currentLength
                if remainingSpace > 100 { // Only add if we have reasonable space
                    let truncated = String(entryContext.prefix(remainingSpace - 20)) + "...\n\n"
                    context += truncated
                }
                break
            }
            
            context += entryContext
            currentLength += entryContext.count
            
            // Update last accessed time
            Task {
                try? await self.databaseManager.updateMemoryAccessTime(entry.memory.id)
            }
        }
        
        if context.isEmpty {
            return "No relevant journal entries found."
        }
        
        return """
        Based on your journal entries:
        
        \(context)
        """
    }
    
    // MARK: - Advanced Retrieval
    
    func searchWithFilters(
        query: String,
        dateRange: DateInterval? = nil,
        moods: [String]? = nil,
        tags: [String]? = nil,
        limit: Int? = nil
    ) async throws -> RetrievalResult {
        logger.info("Searching with filters - moods: \(moods?.joined(separator: ", ") ?? "none"), tags: \(tags?.joined(separator: ", ") ?? "none")")
        
        // First get semantically similar entries
        var results = try await searchRelevantEntries(for: query, limit: (limit ?? defaultResultLimit) * 3)
        
        // Apply filters
        results.entries = results.entries.filter { entry in
            // Date filter
            if let dateRange = dateRange {
                let entryDate = entry.sourceEntry?.createdAt ?? entry.memory.createdAt
                guard dateRange.contains(entryDate) else { return false }
            }
            
            // Mood filter
            if let moods = moods, !moods.isEmpty {
                guard let entryMood = entry.sourceEntry?.mood,
                      moods.contains(entryMood) else { return false }
            }
            
            // Tag filter
            if let tags = tags, !tags.isEmpty {
                let entryTags = entry.memory.tags
                let hasMatchingTag = tags.contains { tag in
                    entryTags.contains(tag)
                }
                guard hasMatchingTag else { return false }
            }
            
            return true
        }
        
        // Limit results
        let resultLimit = limit ?? defaultResultLimit
        results.entries = Array(results.entries.prefix(resultLimit))
        
        return results
    }
}