//
//  ConversationStore.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import Foundation
import GRDB
import os.log

/// Represents a single message in a conversation
struct ConversationMessage: Identifiable, Codable, FetchableRecord, PersistableRecord {
    let id: UUID
    let conversationId: UUID
    let role: String // "user" or "assistant"
    let content: String
    let timestamp: Date
    let contextSources: Data? // JSON encoded array of context sources
    
    init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: String,
        content: String,
        timestamp: Date = Date(),
        contextSources: Data? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.contextSources = contextSources
    }
}

/// Represents a conversation session
struct Conversation: Identifiable, Codable, FetchableRecord, PersistableRecord {
    let id: UUID
    let startedAt: Date
    let lastMessageAt: Date
    let messageCount: Int
    let summary: String?
    
    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        lastMessageAt: Date = Date(),
        messageCount: Int = 0,
        summary: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.lastMessageAt = lastMessageAt
        self.messageCount = messageCount
        self.summary = summary
    }
}

/// Manages conversation history and retrieval
@Observable
@MainActor
final class ConversationStore {
    static let shared = ConversationStore()
    
    private let logger = Logger(subsystem: "com.chaehoshin.Gemi", category: "ConversationStore")
    private let databaseManager = DatabaseManager.shared
    
    private var currentConversationId: UUID?
    private let maxConversationAge: TimeInterval = 60 * 60 * 2 // 2 hours
    
    private init() {
        Task {
            await setupDatabase()
        }
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() async {
        do {
            try await databaseManager.setupConversationTables()
            logger.info("Conversation tables set up successfully")
        } catch {
            logger.error("Failed to setup conversation tables: \(error)")
        }
    }
    
    // MARK: - Conversation Management
    
    /// Get or create current conversation
    func getCurrentConversation() async throws -> UUID {
        // Check if we have a current conversation that's still active
        if let currentId = currentConversationId {
            if let conversation = try await fetchConversation(id: currentId) {
                let age = Date().timeIntervalSince(conversation.lastMessageAt)
                if age < maxConversationAge {
                    return currentId
                }
            }
        }
        
        // Create new conversation
        let newConversation = Conversation()
        try await saveConversation(newConversation)
        currentConversationId = newConversation.id
        
        logger.info("Created new conversation: \(newConversation.id)")
        return newConversation.id
    }
    
    /// Save a message to the current conversation
    func saveMessage(role: String, content: String, contextSources: [ContextSource]? = nil) async throws {
        let conversationId = try await getCurrentConversation()
        
        // Encode context sources if provided
        var contextData: Data? = nil
        if let sources = contextSources {
            contextData = try JSONEncoder().encode(sources.map { source in
                SerializableContextSource(
                    type: source.type.rawValue,
                    title: source.title,
                    preview: source.preview
                )
            })
        }
        
        let message = ConversationMessage(
            conversationId: conversationId,
            role: role,
            content: content,
            contextSources: contextData
        )
        
        try await databaseManager.saveConversationMessage(message)
        
        // Update conversation metadata
        try await updateConversationMetadata(conversationId)
        
        logger.info("Saved message to conversation \(conversationId)")
    }
    
    /// Get recent messages from current or recent conversations
    func getRecentMessages(limit: Int = 20) async throws -> [ConversationMessage] {
        // First try current conversation
        if let currentId = currentConversationId {
            let messages = try await fetchMessages(conversationId: currentId, limit: limit)
            if !messages.isEmpty {
                return messages
            }
        }
        
        // Fall back to most recent conversation
        if let recentConversation = try await fetchMostRecentConversation() {
            return try await fetchMessages(conversationId: recentConversation.id, limit: limit)
        }
        
        return []
    }
    
    /// Search messages across all conversations
    func searchMessages(query: String, limit: Int = 20) async throws -> [ConversationMessage] {
        return try await databaseManager.searchConversationMessages(query: query, limit: limit)
    }
    
    /// Get conversation summary
    func getConversationSummary(conversationId: UUID) async throws -> String? {
        guard let conversation = try await fetchConversation(id: conversationId) else {
            return nil
        }
        
        // If we already have a summary, return it
        if let summary = conversation.summary {
            return summary
        }
        
        // Generate summary using Ollama
        let messages = try await fetchMessages(conversationId: conversationId, limit: 50)
        guard !messages.isEmpty else { return nil }
        
        let conversationText = messages.map { msg in
            "\(msg.role == "user" ? "User" : "Gemi"): \(msg.content)"
        }.joined(separator: "\n")
        
        let summaryPrompt = """
        Summarize this conversation in 2-3 sentences, focusing on the main topics discussed:
        
        \(conversationText)
        """
        
        do {
            let summary = try await OllamaService.shared.generateChat(
                prompt: summaryPrompt,
                model: "gemi-custom"
            )
            
            // Save summary
            var updatedConversation = conversation
            updatedConversation = Conversation(
                id: conversation.id,
                startedAt: conversation.startedAt,
                lastMessageAt: conversation.lastMessageAt,
                messageCount: conversation.messageCount,
                summary: summary
            )
            try await saveConversation(updatedConversation)
            
            return summary
        } catch {
            logger.error("Failed to generate conversation summary: \(error)")
            return nil
        }
    }
    
    /// Get conversation statistics
    func getConversationStats() async throws -> ConversationStats {
        let totalConversations = try await databaseManager.getConversationCount()
        let totalMessages = try await databaseManager.getMessageCount()
        let averageLength = totalConversations > 0 ? Float(totalMessages) / Float(totalConversations) : 0
        
        return ConversationStats(
            totalConversations: totalConversations,
            totalMessages: totalMessages,
            averageMessagesPerConversation: averageLength
        )
    }
    
    // MARK: - Private Methods
    
    private func fetchConversation(id: UUID) async throws -> Conversation? {
        return try await databaseManager.fetchConversation(id: id)
    }
    
    private func saveConversation(_ conversation: Conversation) async throws {
        try await databaseManager.saveConversation(conversation)
    }
    
    private func fetchMessages(conversationId: UUID, limit: Int) async throws -> [ConversationMessage] {
        return try await databaseManager.fetchConversationMessages(
            conversationId: conversationId,
            limit: limit
        )
    }
    
    private func fetchMostRecentConversation() async throws -> Conversation? {
        return try await databaseManager.fetchMostRecentConversation()
    }
    
    private func updateConversationMetadata(_ conversationId: UUID) async throws {
        guard var conversation = try await fetchConversation(id: conversationId) else { return }
        
        let messageCount = try await databaseManager.getMessageCount(for: conversationId)
        
        conversation = Conversation(
            id: conversation.id,
            startedAt: conversation.startedAt,
            lastMessageAt: Date(),
            messageCount: messageCount,
            summary: conversation.summary
        )
        
        try await saveConversation(conversation)
    }
    
    // MARK: - Cleanup
    
    func cleanupOldConversations(olderThan days: Int = 30) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let deletedCount = try await databaseManager.deleteConversationsOlderThan(cutoffDate)
        logger.info("Cleaned up \(deletedCount) old conversations")
    }
}

// MARK: - Supporting Types

struct ConversationStats {
    let totalConversations: Int
    let totalMessages: Int
    let averageMessagesPerConversation: Float
}

struct SerializableContextSource: Codable {
    let type: String
    let title: String
    let preview: String
}

// MARK: - ContextSource Extension

extension ContextSource.ContextType: RawRepresentable {
    typealias RawValue = String
    
    init?(rawValue: String) {
        switch rawValue {
        case "journal": self = .journal
        case "memory": self = .memory
        case "conversation": self = .conversation
        case "analysis": self = .analysis
        default: return nil
        }
    }
    
    var rawValue: String {
        switch self {
        case .journal: return "journal"
        case .memory: return "memory"
        case .conversation: return "conversation"
        case .analysis: return "analysis"
        }
    }
}

// MARK: - DatabaseManager Extensions

extension DatabaseManager {
    func setupConversationTables() async throws {
        try await dbWriter.write { db in
            // Create conversations table
            try db.create(table: "conversations", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("startedAt", .datetime).notNull()
                t.column("lastMessageAt", .datetime).notNull()
                t.column("messageCount", .integer).notNull()
                t.column("summary", .text)
                
                t.column("lastMessageAt").indexed()
            }
            
            // Create messages table
            try db.create(table: "conversationMessages", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("conversationId", .text).notNull()
                    .references("conversations", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("contextSources", .blob)
                
                t.column("conversationId").indexed()
                t.column("timestamp").indexed()
            }
            
            // Create FTS for message search
            if !try db.tableExists("conversationMessages_fts") {
                try db.create(virtualTable: "conversationMessages_fts", using: FTS5()) { t in
                    t.synchronize(withTable: "conversationMessages")
                    t.column("content")
                    t.tokenizer = .porter()
                }
            }
        }
    }
    
    func saveConversation(_ conversation: Conversation) async throws {
        try await dbWriter.write { db in
            try conversation.save(db)
        }
    }
    
    func fetchConversation(id: UUID) async throws -> Conversation? {
        try await dbReader.read { db in
            try Conversation.fetchOne(db, key: id)
        }
    }
    
    func fetchMostRecentConversation() async throws -> Conversation? {
        try await dbReader.read { db in
            try Conversation
                .order(Column("lastMessageAt").desc)
                .fetchOne(db)
        }
    }
    
    func saveConversationMessage(_ message: ConversationMessage) async throws {
        try await dbWriter.write { db in
            try message.save(db)
        }
    }
    
    func fetchConversationMessages(conversationId: UUID, limit: Int) async throws -> [ConversationMessage] {
        try await dbReader.read { db in
            try ConversationMessage
                .filter(Column("conversationId") == conversationId)
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
                .reversed() // Return in chronological order
        }
    }
    
    func searchConversationMessages(query: String, limit: Int) async throws -> [ConversationMessage] {
        try await dbReader.read { db in
            let pattern = FTS5Pattern(matchingAllTokensIn: query)
            
            return try ConversationMessage
                .matching(pattern)
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
    
    func getConversationCount() async throws -> Int {
        try await dbReader.read { db in
            try Conversation.fetchCount(db)
        }
    }
    
    func getMessageCount() async throws -> Int {
        try await dbReader.read { db in
            try ConversationMessage.fetchCount(db)
        }
    }
    
    func getMessageCount(for conversationId: UUID) async throws -> Int {
        try await dbReader.read { db in
            try ConversationMessage
                .filter(Column("conversationId") == conversationId)
                .fetchCount(db)
        }
    }
    
    func deleteConversationsOlderThan(_ date: Date) async throws -> Int {
        try await dbWriter.write { db in
            try Conversation
                .filter(Column("lastMessageAt") < date)
                .deleteAll(db)
        }
    }
}