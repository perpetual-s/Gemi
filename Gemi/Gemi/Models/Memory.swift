//
//  Memory.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import Foundation
import GRDB

/// Represents a memory snippet that Gemi remembers from conversations or journal entries
struct Memory: Identifiable, Codable, FetchableRecord, PersistableRecord {
    // MARK: - Properties
    
    /// Unique identifier for the memory
    let id: UUID
    
    /// The actual memory content/snippet
    let content: String
    
    /// Vector embedding for semantic search (stored as Data)
    let embedding: Data?
    
    /// Reference to the source journal entry if applicable
    let sourceEntryId: UUID?
    
    /// When this memory was created
    let createdAt: Date
    
    /// Last time this memory was accessed or used
    var lastAccessedAt: Date
    
    /// Importance score (0.0 to 1.0) - how relevant/important this memory is
    var importance: Float
    
    /// Tags for categorization
    var tags: [String]
    
    /// Whether this memory is pinned (always kept)
    var isPinned: Bool
    
    /// Memory type for different sources
    let memoryType: MemoryType
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        content: String,
        embedding: Data? = nil,
        sourceEntryId: UUID? = nil,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        importance: Float = 0.5,
        tags: [String] = [],
        isPinned: Bool = false,
        memoryType: MemoryType = .conversation
    ) {
        self.id = id
        self.content = content
        self.embedding = embedding
        self.sourceEntryId = sourceEntryId
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.importance = importance
        self.tags = tags
        self.isPinned = isPinned
        self.memoryType = memoryType
    }
    
    // MARK: - GRDB Configuration
    
    static let databaseTableName = "memories"
    
    enum Columns: String, ColumnExpression {
        case id
        case content
        case embedding
        case sourceEntryId
        case createdAt
        case lastAccessedAt
        case importance
        case tags
        case isPinned
        case memoryType
    }
}

// MARK: - Memory Type

enum MemoryType: String, Codable, CaseIterable {
    case conversation = "conversation"     // From AI chat
    case journalFact = "journal_fact"      // Extracted from journal
    case userProvided = "user_provided"    // Explicitly told by user
    case reflection = "reflection"         // AI's reflection/summary
    
    var displayName: String {
        switch self {
        case .conversation:
            return "Conversation"
        case .journalFact:
            return "Journal Fact"
        case .userProvided:
            return "You told me"
        case .reflection:
            return "Reflection"
        }
    }
    
    var icon: String {
        switch self {
        case .conversation:
            return "bubble.left.and.bubble.right"
        case .journalFact:
            return "book.pages"
        case .userProvided:
            return "person.bubble"
        case .reflection:
            return "sparkles"
        }
    }
}

// MARK: - Database Migration

extension Memory {
    /// Create the memories table
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, options: .ifNotExists) { t in
            t.column("id", .text).notNull().primaryKey()
            t.column("content", .text).notNull()
            t.column("embedding", .blob)
            t.column("sourceEntryId", .text)
            t.column("createdAt", .datetime).notNull()
            t.column("lastAccessedAt", .datetime).notNull()
            t.column("importance", .double).notNull()
            t.column("tags", .text).notNull() // JSON array
            t.column("isPinned", .boolean).notNull().defaults(to: false)
            t.column("memoryType", .text).notNull()
            
            // Indexes for performance
            t.column("createdAt").indexed()
            t.column("importance").indexed()
            t.column("sourceEntryId").indexed()
            t.column("memoryType").indexed()
        }
        
        // Create FTS table for content search
        try db.create(virtualTable: "memories_fts", using: FTS5()) { t in
            t.content(Memory.self)
            t.column(Memory.Columns.content)
            t.tokenizer = .porter()
        }
    }
}

// MARK: - Computed Properties

extension Memory {
    /// Calculate age of memory for decay calculations
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }
    
    /// Calculate decayed importance based on age and access
    var decayedImportance: Float {
        // Pinned memories don't decay
        guard !isPinned else { return importance }
        
        // Calculate time-based decay
        let daysSinceCreation = Float(ageInDays)
        let daysSinceAccess = Float(
            Calendar.current.dateComponents([.day], from: lastAccessedAt, to: Date()).day ?? 0
        )
        
        // Apply decay formula (memories lose importance over time if not accessed)
        let creationDecay = exp(-daysSinceCreation / 365.0) // Slower decay over a year
        let accessDecay = exp(-daysSinceAccess / 30.0)      // Faster decay if not accessed
        
        return importance * creationDecay * accessDecay
    }
    
    /// Get embedding as array of doubles for similarity calculations
    func getEmbeddingVector() -> [Double]? {
        guard let embedding = embedding else { return nil }
        
        // Convert Data to [Double]
        let count = embedding.count / MemoryLayout<Double>.size
        return embedding.withUnsafeBytes { bytes in
            Array(UnsafeBufferPointer(
                start: bytes.bindMemory(to: Double.self).baseAddress,
                count: count
            ))
        }
    }
}

// MARK: - Search Support

extension Memory {
    /// Calculate cosine similarity between two embedding vectors
    static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        
        var dotProduct = 0.0
        var normA = 0.0
        var normB = 0.0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        
        guard normA > 0 && normB > 0 else { return 0 }
        return dotProduct / (sqrt(normA) * sqrt(normB))
    }
    
    /// Convert array of doubles to Data for storage
    static func embeddingToData(_ embedding: [Double]) -> Data {
        return embedding.withUnsafeBytes { bytes in
            Data(bytes)
        }
    }
}

// MARK: - Display Helpers

extension Memory {
    /// Get a preview of the content suitable for UI display
    var preview: String {
        let maxLength = 100
        if content.count <= maxLength {
            return content
        }
        return String(content.prefix(maxLength)) + "..."
    }
    
    /// Format the memory for display with context
    var formattedDisplay: String {
        var result = content
        
        if !tags.isEmpty {
            result += "\n[Tags: \(tags.joined(separator: ", "))]"
        }
        
        return result
    }
    
    /// Get relative time string
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}