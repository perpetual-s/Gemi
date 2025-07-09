import Foundation
import SQLite3
import CryptoKit
import Security

// SQLite3 constants not exposed in Swift
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Thread-safe database manager using actor isolation for Swift 6 compliance
actor DatabaseManager {
    static let shared = DatabaseManager()
    
    private let databaseName = "gemi.db"
    private let encryptionKeyTag = "com.gemi.encryptionKey"
    private var database: OpaquePointer?
    
    private init() {}
    
    /// Test if the database connection is working
    func testConnection() async -> Bool {
        guard let db = database else {
            return false
        }
        
        // Try a simple query to test connection
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(db, "SELECT 1", -1, &statement, nil) == SQLITE_OK
        sqlite3_finalize(statement)
        
        return result
    }
    
    func initialize() async throws {
        if database != nil {
            return // Already initialized
        }
        
        do {
            try setupDatabase()
        } catch {
            print("Database initialization failed: \(error)")
            // Try to reset and reinitialize
            resetDatabase()
            try setupDatabase()
        }
    }
    
    private func resetDatabase() {
        if let db = database {
            sqlite3_close(db)
            database = nil
        }
        
        // Delete the database file to start fresh
        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let bundleID = Bundle.main.bundleIdentifier ?? "com.gemi.app"
            let appDirectory = appSupportURL.appendingPathComponent(bundleID)
            let databaseURL = appDirectory.appendingPathComponent(databaseName)
            
            if FileManager.default.fileExists(atPath: databaseURL.path) {
                try FileManager.default.removeItem(at: databaseURL)
                print("Database file deleted")
            }
        } catch {
            print("Failed to delete database file: \(error)")
        }
    }
    
    private func setupDatabase() throws {
        // Use application support directory for sandboxed apps
        let appSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        // Create app-specific directory
        let bundleID = Bundle.main.bundleIdentifier ?? "com.gemi.app"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID)
        
        // Check if directory exists, create if needed
        if !FileManager.default.fileExists(atPath: appDirectory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: appDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                print("Failed to create app directory: \(error)")
                throw DatabaseError.failedToOpen
            }
        }
        
        let databaseURL = appDirectory.appendingPathComponent(databaseName)
        
        print("Database path: \(databaseURL.path)")
        
        if sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(database))
            print("Failed to open database: \(errorMessage)")
            throw DatabaseError.failedToOpen
        }
        
        // Enable WAL mode for better concurrency
        sqlite3_exec(database, "PRAGMA journal_mode=WAL", nil, nil, nil)
        
        // Ensure proper file permissions
        do {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: databaseURL.path
            )
        } catch {
            print("Failed to set file permissions: \(error)")
            // Non-critical, continue
        }
        
        try createTables()
    }
    
    private func createTables() throws {
        let createEntriesTable = """
            CREATE TABLE IF NOT EXISTS entries (
                id TEXT PRIMARY KEY,
                title TEXT,
                content_encrypted BLOB NOT NULL,
                created_at REAL NOT NULL,
                modified_at REAL NOT NULL,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                mood TEXT,
                tags TEXT,
                location TEXT,
                weather TEXT
            )
        """
        
        guard let db = database else {
            throw DatabaseError.notInitialized
        }
        
        // Execute table creation
        if sqlite3_exec(db, createEntriesTable, nil, nil, nil) != SQLITE_OK {
            throw DatabaseError.failedToCreateTable
        }
        
        // Handle memories table migration
        try migrateMemoriesTable()
        
        // Create indexes for better performance
        let createIndexes = [
            "CREATE INDEX IF NOT EXISTS idx_entries_created_at ON entries(created_at DESC)",
            "CREATE INDEX IF NOT EXISTS idx_entries_is_favorite ON entries(is_favorite)",
            "CREATE INDEX IF NOT EXISTS idx_memories_source_entry_id ON memories(source_entry_id)"
        ]
        
        // Create indexes
        for createIndex in createIndexes {
            sqlite3_exec(db, createIndex, nil, nil, nil)
        }
    }
    
    private func migrateMemoriesTable() throws {
        guard let db = database else {
            throw DatabaseError.notInitialized
        }
        
        // Check if memories table exists and what columns it has
        let tableInfoQuery = "PRAGMA table_info(memories)"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, tableInfoQuery, -1, &statement, nil) == SQLITE_OK else {
            // Table doesn't exist, create new one
            let createMemoriesTable = """
                CREATE TABLE IF NOT EXISTS memories (
                    id TEXT PRIMARY KEY,
                    content TEXT NOT NULL,
                    source_entry_id TEXT NOT NULL,
                    extracted_at REAL NOT NULL,
                    FOREIGN KEY (source_entry_id) REFERENCES entries(id) ON DELETE CASCADE
                )
            """
            
            if sqlite3_exec(db, createMemoriesTable, nil, nil, nil) != SQLITE_OK {
                throw DatabaseError.failedToCreateTable
            }
            return
        }
        
        // Check column names
        var hasOldSchema = false
        var hasNewSchema = false
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let namePtr = sqlite3_column_text(statement, 1) {
                let columnName = String(cString: namePtr)
                if columnName == "entry_id" {
                    hasOldSchema = true
                } else if columnName == "source_entry_id" {
                    hasNewSchema = true
                }
            }
        }
        
        if hasOldSchema && !hasNewSchema {
            // Need to migrate from old schema to new
            print("Migrating memories table from old schema to new schema...")
            
            // Create new table with correct schema
            let createNewTable = """
                CREATE TABLE memories_new (
                    id TEXT PRIMARY KEY,
                    content TEXT NOT NULL,
                    source_entry_id TEXT NOT NULL,
                    extracted_at REAL NOT NULL,
                    FOREIGN KEY (source_entry_id) REFERENCES entries(id) ON DELETE CASCADE
                )
            """
            
            if sqlite3_exec(db, createNewTable, nil, nil, nil) != SQLITE_OK {
                throw DatabaseError.failedToCreateTable
            }
            
            // Copy data from old table to new (if any exists)
            let migrateData = """
                INSERT INTO memories_new (id, content, source_entry_id, extracted_at)
                SELECT id, 
                       COALESCE(content, ''), 
                       entry_id,
                       COALESCE(created_at, strftime('%s', 'now'))
                FROM memories
            """
            
            sqlite3_exec(db, migrateData, nil, nil, nil)
            
            // Drop old table and rename new one
            sqlite3_exec(db, "DROP TABLE memories", nil, nil, nil)
            sqlite3_exec(db, "ALTER TABLE memories_new RENAME TO memories", nil, nil, nil)
            
            print("Memory table migration completed successfully")
        } else if !hasOldSchema && !hasNewSchema {
            // Empty or corrupted table, recreate it
            sqlite3_exec(db, "DROP TABLE IF EXISTS memories", nil, nil, nil)
            
            let createMemoriesTable = """
                CREATE TABLE memories (
                    id TEXT PRIMARY KEY,
                    content TEXT NOT NULL,
                    source_entry_id TEXT NOT NULL,
                    extracted_at REAL NOT NULL,
                    FOREIGN KEY (source_entry_id) REFERENCES entries(id) ON DELETE CASCADE
                )
            """
            
            if sqlite3_exec(db, createMemoriesTable, nil, nil, nil) != SQLITE_OK {
                throw DatabaseError.failedToCreateTable
            }
        }
        // If hasNewSchema is true, table is already in correct format
    }
    
    // MARK: - Entry Operations
    
    func saveEntry(_ entry: JournalEntry) async throws {
        guard let db = database else {
            throw DatabaseError.notInitialized
        }
        
        let encryptedContent = try await encryptContent(entry.content)
        
        let query = """
            INSERT OR REPLACE INTO entries 
            (id, title, content_encrypted, created_at, modified_at, is_favorite, mood, tags, location, weather)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToPrepareStatement
        }
        
        // Bind parameters
        sqlite3_bind_text(statement, 1, entry.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, entry.title, -1, SQLITE_TRANSIENT)
        _ = encryptedContent.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, 3, bytes.baseAddress, Int32(encryptedContent.count), SQLITE_TRANSIENT)
        }
        sqlite3_bind_double(statement, 4, entry.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 5, entry.modifiedAt.timeIntervalSince1970)
        sqlite3_bind_int(statement, 6, entry.isFavorite ? 1 : 0)
        
        if let mood = entry.mood {
            sqlite3_bind_text(statement, 7, mood.rawValue, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 7)
        }
        
        if !entry.tags.isEmpty {
            let tagsJSON = try JSONEncoder().encode(entry.tags)
            let tagsString = String(data: tagsJSON, encoding: .utf8)
            sqlite3_bind_text(statement, 8, tagsString, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 8)
        }
        
        if let location = entry.location {
            sqlite3_bind_text(statement, 9, location, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 9)
        }
        
        if let weather = entry.weather {
            sqlite3_bind_text(statement, 10, weather, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 10)
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.failedToSave
        }
    }
    
    func loadEntries() async throws -> [JournalEntry] {
        guard let db = database else {
            throw DatabaseError.notInitialized
        }
        
        let query = """
            SELECT id, title, content_encrypted, created_at, modified_at, is_favorite, mood, tags, location, weather
            FROM entries
            ORDER BY created_at DESC
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToPrepareStatement
        }
        
        var entries: [JournalEntry] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idString = sqlite3_column_text(statement, 0),
                  let id = UUID(uuidString: String(cString: idString)) else {
                continue
            }
            
            let title = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            
            let encryptedContentPointer = sqlite3_column_blob(statement, 2)
            let encryptedContentSize = Int(sqlite3_column_bytes(statement, 2))
            let encryptedContent = Data(bytes: encryptedContentPointer!, count: encryptedContentSize)
            
            let content = try await decryptContent(encryptedContent)
            
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
            let modifiedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
            let isFavorite = sqlite3_column_int(statement, 5) == 1
            
            let moodString = sqlite3_column_text(statement, 6).map { String(cString: $0) }
            let mood = moodString.flatMap { Mood(rawValue: $0) }
            
            var tags: [String] = []
            if let tagsText = sqlite3_column_text(statement, 7),
               let tagsData = String(cString: tagsText).data(using: .utf8) {
                tags = (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
            }
            
            let location = sqlite3_column_text(statement, 8).map { String(cString: $0) }
            let weather = sqlite3_column_text(statement, 9).map { String(cString: $0) }
            
            let entry = JournalEntry(
                id: id,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                title: title,
                content: content,
                tags: tags,
                mood: mood,
                weather: weather,
                location: location,
                isFavorite: isFavorite
            )
            
            entries.append(entry)
        }
        
        return entries
    }
    
    func searchEntries(query: String) async throws -> [JournalEntry] {
        guard let db = database else {
            throw DatabaseError.notInitialized
        }
        
        // Get ALL entries and filter in code for comprehensive search
        let sql = """
            SELECT id, title, content_encrypted, created_at, modified_at, is_favorite, mood, tags, location, weather
            FROM entries
            ORDER BY created_at DESC
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToPrepareStatement
        }
        
        var entries: [JournalEntry] = []
        let lowercasedQuery = query.lowercased()
        
        // Debug: Print search query
        print("Searching for: '\(query)'")
        
        var totalEntriesFound = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            totalEntriesFound += 1
            guard let idString = sqlite3_column_text(statement, 0),
                  let id = UUID(uuidString: String(cString: idString)) else {
                continue
            }
            
            let title = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            
            let encryptedContentPointer = sqlite3_column_blob(statement, 2)
            let encryptedContentSize = Int(sqlite3_column_bytes(statement, 2))
            let encryptedContent = Data(bytes: encryptedContentPointer!, count: encryptedContentSize)
            
            let content = try await decryptContent(encryptedContent)
            
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
            let modifiedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
            let isFavorite = sqlite3_column_int(statement, 5) == 1
            
            let moodString = sqlite3_column_text(statement, 6).map { String(cString: $0) }
            let mood = moodString.flatMap { Mood(rawValue: $0) }
            
            var tags: [String] = []
            if let tagsText = sqlite3_column_text(statement, 7),
               let tagsData = String(cString: tagsText).data(using: .utf8) {
                tags = (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
            }
            
            let location = sqlite3_column_text(statement, 8).map { String(cString: $0) }
            let weather = sqlite3_column_text(statement, 9).map { String(cString: $0) }
            
            // Check if content contains the search query (case-insensitive)
            let contentMatches = content.lowercased().contains(lowercasedQuery)
            let titleMatches = title.lowercased().contains(lowercasedQuery)
            let tagsMatch = tags.contains { $0.lowercased().contains(lowercasedQuery) }
            let moodMatches = mood?.rawValue.lowercased().contains(lowercasedQuery) ?? false
            
            // Debug: Print match results
            if title.lowercased().contains("powerball") || content.lowercased().contains("powerball") {
                print("Found Powerball entry - Title: \(title), Content preview: \(String(content.prefix(50)))")
                print("Match results - Title: \(titleMatches), Content: \(contentMatches), Tags: \(tagsMatch), Mood: \(moodMatches)")
            }
            
            // Only include entry if it matches in title, tags, mood, or content
            if titleMatches || tagsMatch || moodMatches || contentMatches {
                let entry = JournalEntry(
                    id: id,
                    createdAt: createdAt,
                    modifiedAt: modifiedAt,
                    title: title,
                    content: content,
                    tags: tags,
                    mood: mood,
                    weather: weather,
                    location: location,
                    isFavorite: isFavorite
                )
                
                entries.append(entry)
            }
        }
        
        print("Total entries in database: \(totalEntriesFound), Matching entries: \(entries.count)")
        return entries
    }
    
    func deleteEntry(_ id: UUID) async throws {
        guard let db = database else {
            throw DatabaseError.notInitialized
        }
        
        let query = "DELETE FROM entries WHERE id = ?"
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToPrepareStatement
        }
        
        sqlite3_bind_text(statement, 1, id.uuidString, -1, SQLITE_TRANSIENT)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.failedToDelete
        }
    }
    
    // MARK: - Memory Operations
    // Note: Old DatabaseMemory-based function removed - use saveMemory(_ memoryData: MemoryData) instead
    
    func searchMemories(query: String, limit: Int = 10) async throws -> [DatabaseMemory] {
        guard let db = database else {
            throw DatabaseError.notInitialized
        }
        
        let sql = """
            SELECT id, source_entry_id, content, extracted_at
            FROM memories
            WHERE content LIKE ?
            ORDER BY extracted_at DESC
            LIMIT ?
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToPrepareStatement
        }
        
        let searchPattern = "%\(query)%"
        sqlite3_bind_text(statement, 1, searchPattern, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(limit))
        
        var memories: [DatabaseMemory] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idString = sqlite3_column_text(statement, 0),
                  let id = UUID(uuidString: String(cString: idString)),
                  let entryIdString = sqlite3_column_text(statement, 1),
                  let entryId = UUID(uuidString: String(cString: entryIdString)),
                  let content = sqlite3_column_text(statement, 2) else {
                continue
            }
            
            let extractedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
            
            // Note: DatabaseMemory still uses old property names for compatibility
            let memory = DatabaseMemory(
                id: id,
                entryId: entryId,
                content: String(cString: content),
                keywords: [], // No longer using keywords
                createdAt: extractedAt
            )
            
            memories.append(memory)
        }
        
        return memories
    }
    
    // MARK: - Encryption
    
    private func getOrCreateEncryptionKey() async throws -> SymmetricKey {
        // Try to retrieve existing key from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: encryptionKeyTag,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let keyData = result as? Data {
            return SymmetricKey(data: keyData)
        }
        
        // Generate new key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // Store in Keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: encryptionKeyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw DatabaseError.encryptionError
        }
        
        return key
    }
    
    private func encryptContent(_ content: String) async throws -> Data {
        let key = try await getOrCreateEncryptionKey()
        guard let contentData = content.data(using: .utf8) else {
            throw DatabaseError.encryptionError
        }
        
        let sealedBox = try AES.GCM.seal(contentData, using: key)
        guard let encrypted = sealedBox.combined else {
            throw DatabaseError.encryptionError
        }
        
        return encrypted
    }
    
    private func decryptContent(_ encryptedData: Data) async throws -> String {
        let key = try await getOrCreateEncryptionKey()
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let content = String(data: decryptedData, encoding: .utf8) else {
            throw DatabaseError.decryptionError
        }
        
        return content
    }
    
    // MARK: - Memory Management
    
    func saveMemory(_ memoryData: MemoryData) async throws {
        guard let db = database else {
            throw DatabaseError.notInitialized
        }
        
        let insertQuery = """
            INSERT OR REPLACE INTO memories (id, content, source_entry_id, extracted_at)
            VALUES (?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToPrepareStatement
        }
        
        sqlite3_bind_text(statement, 1, memoryData.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, memoryData.content, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, memoryData.sourceEntryID.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 4, memoryData.extractedAt.timeIntervalSince1970)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.failedToSave
        }
    }
    
    func loadAllMemories() async throws -> [MemoryData] {
        guard let db = database else {
            throw DatabaseError.notInitialized
        }
        
        let query = """
            SELECT id, content, source_entry_id, extracted_at
            FROM memories
            ORDER BY extracted_at DESC
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToPrepareStatement
        }
        
        var memories: [MemoryData] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idString = sqlite3_column_text(statement, 0),
                  let id = UUID(uuidString: String(cString: idString)),
                  let content = sqlite3_column_text(statement, 1),
                  let sourceEntryIdString = sqlite3_column_text(statement, 2),
                  let sourceEntryId = UUID(uuidString: String(cString: sourceEntryIdString)) else {
                continue
            }
            
            let extractedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
            
            let memoryData = MemoryData(
                id: id,
                content: String(cString: content),
                sourceEntryID: sourceEntryId,
                extractedAt: extractedAt
            )
            
            memories.append(memoryData)
        }
        
        return memories
    }
    
    // Memory deletion methods that work with IDs (Sendable)
    func deleteMemoryByID(_ id: UUID) async throws {
        guard let db = database else {
            throw DatabaseError.notInitialized
        }
        
        let query = "DELETE FROM memories WHERE id = ?"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToPrepareStatement
        }
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, id.uuidString, -1, SQLITE_TRANSIENT)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.failedToDelete
        }
    }
    
    func clearAllMemoriesFromDB() async throws {
        guard let db = database else {
            throw DatabaseError.notInitialized
        }
        
        let query = "DELETE FROM memories"
        
        guard sqlite3_exec(db, query, nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.failedToDelete
        }
    }
}

// MARK: - Database Errors

enum DatabaseError: LocalizedError {
    case notInitialized
    case failedToOpen
    case failedToCreateTable
    case failedToPrepareStatement
    case failedToSave
    case failedToDelete
    case encryptionError
    case decryptionError
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database not initialized"
        case .failedToOpen:
            return "Failed to open database"
        case .failedToCreateTable:
            return "Failed to create database tables"
        case .failedToPrepareStatement:
            return "Failed to prepare SQL statement"
        case .failedToSave:
            return "Failed to save to database"
        case .failedToDelete:
            return "Failed to delete from database"
        case .encryptionError:
            return "Failed to encrypt data"
        case .decryptionError:
            return "Failed to decrypt data"
        }
    }
}

// MARK: - Database Memory Model

struct DatabaseMemory: Identifiable {
    let id: UUID
    let entryId: UUID
    let content: String
    let keywords: [String]
    let createdAt: Date
}