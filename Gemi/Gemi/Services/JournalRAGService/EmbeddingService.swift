//
//  EmbeddingService.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import Foundation
import os.log

@MainActor
final class EmbeddingService {
    private let logger = Logger(subsystem: "com.chaehoshin.Gemi", category: "EmbeddingService")
    private let ollamaService = OllamaService.shared
    private let databaseManager = DatabaseManager.shared
    
    private let embeddingModel = "nomic-embed-text"
    private let maxBatchSize = 10
    
    // MARK: - Embedding Generation
    
    func generateEmbedding(for text: String) async throws -> [Float] {
        logger.info("Generating embedding for text of length: \(text.count)")
        
        do {
            let response = try await ollamaService.generateEmbedding(
                prompt: text,
                model: embeddingModel
            )
            
            // Convert Double array to Float array
            let embedding = response.embedding.map { Float($0) }
            
            logger.info("Successfully generated embedding with \(embedding.count) dimensions")
            return embedding
        } catch {
            logger.error("Failed to generate embedding: \(error.localizedDescription)")
            throw EmbeddingError.generationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Batch Processing
    
    func batchProcessEntries() async throws {
        logger.info("Starting batch processing of journal entries")
        
        do {
            let entries = try await databaseManager.fetchEntriesWithoutEmbeddings()
            logger.info("Found \(entries.count) entries without embeddings")
            
            for batch in entries.chunked(into: maxBatchSize) {
                await processBatch(batch)
            }
            
            logger.info("Completed batch processing")
        } catch {
            logger.error("Batch processing failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func processBatch(_ entries: [JournalEntry]) async {
        await withTaskGroup(of: Void.self) { group in
            for entry in entries {
                group.addTask {
                    do {
                        let embedding = try await self.generateEmbedding(for: entry.content)
                        try await self.storeEmbedding(
                            entryId: entry.id,
                            text: entry.content,
                            embedding: embedding
                        )
                    } catch {
                        self.logger.error("Failed to process entry \(entry.id): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Storage
    
    func storeEmbedding(entryId: UUID, text: String, embedding: [Float]) async throws {
        logger.info("Storing embedding for entry: \(entryId)")
        
        // Convert embedding to Data for storage
        let embeddingData = embedding.withUnsafeBytes { Data($0) }
        
        // Create memory record for the embedding
        let memory = Memory(
            content: String(text.prefix(500)), // Store preview for quick reference
            embedding: embeddingData,
            sourceEntryId: entryId,
            importance: 0.5,
            tags: [],
            isPinned: false,
            memoryType: .journalFact
        )
        
        do {
            try await databaseManager.saveMemory(memory)
            logger.info("Successfully stored embedding for entry: \(entryId)")
        } catch {
            logger.error("Failed to store embedding: \(error.localizedDescription)")
            throw EmbeddingError.storageFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupOrphanedEmbeddings() async throws {
        logger.info("Cleaning up orphaned embeddings")
        
        do {
            let deletedCount = try await databaseManager.deleteOrphanedMemories()
            logger.info("Deleted \(deletedCount) orphaned embeddings")
        } catch {
            logger.error("Failed to cleanup orphaned embeddings: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Error Types
    
    enum EmbeddingError: LocalizedError {
        case noEmbeddingReturned
        case generationFailed(String)
        case storageFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .noEmbeddingReturned:
                return "No embedding was returned from the model"
            case .generationFailed(let message):
                return "Failed to generate embedding: \(message)"
            case .storageFailed(let message):
                return "Failed to store embedding: \(message)"
            }
        }
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}