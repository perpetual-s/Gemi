import Foundation
import GRDB

/// A journal entry model representing a single diary entry in the Gemi app.
/// This model provides the foundation for encrypted local storage of user's personal journal content.
///
/// Privacy Note: The `content` field will be encrypted before storage using AES-256-GCM.
/// All data processing occurs locally - no journal content ever leaves the user's device.
struct JournalEntry: Sendable {
    /// Unique identifier for the journal entry
    let id: UUID
    
    /// The date and time when the journal entry was created
    let date: Date
    
    /// Optional title for the journal entry
    var title: String
    
    /// The main content of the journal entry
    /// Note: This will be encrypted before database storage for privacy protection
    var content: String
    
    /// Optional mood indicator for the entry
    var mood: String?
    
    /// Alias for date property to match TimelineCardView expectations
    var createdAt: Date { date }
    
    /// Creates a new journal entry with the current date
    /// - Parameters:
    ///   - title: Optional title for the entry
    ///   - content: The journal entry content to store
    ///   - mood: Optional mood indicator
    init(title: String = "", content: String, mood: String? = nil) {
        self.id = UUID()
        self.date = Date()
        self.title = title
        self.content = content
        self.mood = mood
    }
    
    /// Creates a journal entry with all fields specified (for database reconstruction)
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - date: Creation date
    ///   - title: Entry title
    ///   - content: Journal content
    ///   - mood: Optional mood indicator
    init(id: UUID, date: Date, title: String, content: String, mood: String? = nil) {
        self.id = id
        self.date = date
        self.title = title
        self.content = content
        self.mood = mood
    }
}

// MARK: - GRDB Database Conformance

extension JournalEntry: FetchableRecord, PersistableRecord {
    /// Database table name for journal entries
    static let databaseTableName = "entries"
    
    /// Database column names
    enum Columns {
        static let id = Column("id")
        static let date = Column("date")
        static let title = Column("title")
        static let content = Column("content")
        static let mood = Column("mood")
    }
    
    /// Initialize from database row
    init(row: Row) throws {
        id = row[Columns.id]
        date = row[Columns.date]
        // Handle legacy entries that might not have a title column
        title = row[Columns.title] ?? ""
        content = row[Columns.content]
        mood = row[Columns.mood]
    }
    
    /// Encode to database row
    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.date] = date
        container[Columns.title] = title
        container[Columns.content] = content
        container[Columns.mood] = mood
    }
}

// MARK: - Database Table Schema

extension JournalEntry {
    /// Creates the database table schema for journal entries
    /// - Parameter db: Database connection
    /// - Throws: Database errors during table creation
    static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { table in
            table.primaryKey("id", .text).notNull()
            table.column("date", .datetime).notNull()
            table.column("title", .text).notNull()
            table.column("content", .text).notNull()
            table.column("mood", .text)
        }
        
        // Create index on date for efficient timeline queries
        try db.create(index: "idx_entries_date", on: databaseTableName, columns: ["date"], ifNotExists: true)
    }
}

// MARK: - Convenience Query Methods

extension JournalEntry {
    /// Fetches all journal entries ordered by date (newest first)
    /// - Parameter db: Database connection
    /// - Returns: Array of journal entries sorted by date descending
    /// - Throws: Database errors during fetch
    static func fetchAllOrderedByDate(_ db: Database) throws -> [JournalEntry] {
        return try JournalEntry
            .order(Columns.date.desc)
            .fetchAll(db)
    }
    
    /// Fetches journal entries with pagination support
    /// - Parameters:
    ///   - db: Database connection
    ///   - limit: Maximum number of entries to fetch
    ///   - offset: Number of entries to skip
    /// - Returns: Array of journal entries sorted by date descending
    /// - Throws: Database errors during fetch
    static func fetchWithPagination(_ db: Database, limit: Int, offset: Int) throws -> [JournalEntry] {
        return try JournalEntry
            .order(Columns.date.desc)
            .limit(limit, offset: offset)
            .fetchAll(db)
    }
    
    /// Fetches journal entries within a date range
    /// - Parameters:
    ///   - db: Database connection
    ///   - startDate: Start date for the range (inclusive)
    ///   - endDate: End date for the range (inclusive)
    /// - Returns: Array of journal entries within the specified date range
    /// - Throws: Database errors during fetch
    static func fetchEntriesInDateRange(_ db: Database, from startDate: Date, to endDate: Date) throws -> [JournalEntry] {
        return try JournalEntry
            .filter(Columns.date >= startDate && Columns.date <= endDate)
            .order(Columns.date.desc)
            .fetchAll(db)
    }
    
    /// Fetches a journal entry by its unique identifier
    /// - Parameters:
    ///   - db: Database connection
    ///   - id: The UUID of the journal entry to fetch
    /// - Returns: The journal entry if found, nil otherwise
    /// - Throws: Database errors during fetch
    static func fetchEntry(_ db: Database, id: UUID) throws -> JournalEntry? {
        return try JournalEntry
            .filter(Columns.id == id)
            .fetchOne(db)
    }
}

// MARK: - Identifiable Conformance for SwiftUI

extension JournalEntry: Identifiable {
    // id property already exists, satisfying Identifiable protocol
}

// MARK: - Hashable and Equatable Conformance

extension JournalEntry: Hashable, Equatable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: JournalEntry, rhs: JournalEntry) -> Bool {
        return lhs.id == rhs.id &&
               lhs.date == rhs.date &&
               lhs.title == rhs.title &&
               lhs.content == rhs.content &&
               lhs.mood == rhs.mood
    }
} 