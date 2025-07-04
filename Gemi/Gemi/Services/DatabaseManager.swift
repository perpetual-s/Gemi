import Foundation
import GRDB
import CryptoKit
import Security

/// DatabaseManager handles all encrypted local storage operations for Gemi journal entries.
/// 
/// Privacy & Security Features:
/// - AES-256-GCM encryption for all journal content
/// - Encryption keys stored securely in macOS Keychain
/// - SQLite database stored in Application Support directory
/// - All operations occur locally - no cloud sync or external communication
/// 
/// Thread Safety: This class is designed to be used with Swift concurrency (async/await).
@Observable
final class DatabaseManager: Sendable {
    
    // MARK: - Singleton
    
    private static let _shared: DatabaseManager? = {
        do {
            return try DatabaseManager()
        } catch {
            print("❌ Failed to initialize DatabaseManager singleton: \(error)")
            return nil
        }
    }()
    
    /// Thread-safe access to the shared DatabaseManager instance
    /// - Throws: DatabaseError if initialization fails
    static func shared() throws -> DatabaseManager {
        guard let manager = _shared else {
            throw DatabaseError.initializationFailed("Failed to initialize DatabaseManager singleton")
        }
        return manager
    }
    
    // MARK: - Properties
    
    /// The GRDB database queue for thread-safe operations
    private let dbQueue: DatabaseQueue
    
    /// Database writer for write operations
    var dbWriter: DatabaseWriter { dbQueue }
    
    /// Database reader for read operations
    var dbReader: DatabaseReader { dbQueue }
    
    /// Keychain service identifier for storing encryption keys
    private static let keychainService = "dev.perpetual-s.Gemi"
    private static let keychainAccount = "journal-encryption-key"
    
    /// Database file name
    private static let databaseFileName = "Gemi.sqlite"
    
    // MARK: - Initialization
    
    /// Initializes the DatabaseManager with encrypted SQLite database
    /// - Throws: DatabaseError if initialization fails
    init() throws {
        // Get Application Support directory
        let applicationSupportURL = try Self.getApplicationSupportDirectory()
        let databaseURL = applicationSupportURL.appendingPathComponent(Self.databaseFileName)
        
        // Initialize database queue
        self.dbQueue = try DatabaseQueue(path: databaseURL.path)
        
        // Setup database schema
        try setupDatabase()
        
        print("DatabaseManager initialized successfully")
        print("Database location: \(databaseURL.path)")
    }
    
    // MARK: - Database Setup
    
    /// Sets up the database schema and ensures all tables exist
    /// - Throws: Database errors during setup
    private func setupDatabase() throws {
        // Configure database pragmas outside of any transaction
        try dbQueue.inDatabase { db in
            // Enable WAL mode for better concurrency
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            
            // Enable foreign key constraints
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            
            // Set a reasonable timeout for busy connections
            try db.execute(sql: "PRAGMA busy_timeout = 5000")
        }
        
        // Create tables and handle migrations in a separate transaction
        try dbQueue.write { db in
            // Check if the entries table exists
            let tableExists = try db.tableExists("entries")
            
            if tableExists {
                // Table exists, check if we need to migrate
                try migrateDatabase(db)
            } else {
                // Create the journal entries table fresh
                try JournalEntry.createTable(db)
            }
            
            // Create memories table
            try Memory.createTable(in: db)
            
            print("Database schema initialized")
        }
    }
    
    /// Migrates the database schema to add missing columns
    /// - Parameter db: Database connection
    /// - Throws: Database errors during migration
    private func migrateDatabase(_ db: Database) throws {
        // Check if title column exists
        let columns = try db.columns(in: "entries")
        let columnNames = columns.map { $0.name }
        
        if !columnNames.contains("title") {
            print("Migrating database: Adding 'title' column")
            try db.alter(table: "entries") { table in
                table.add(column: "title", .text).defaults(to: "")
            }
            print("Database migration completed: 'title' column added")
        }
        
        if !columnNames.contains("mood") {
            print("Migrating database: Adding 'mood' column")
            try db.alter(table: "entries") { table in
                table.add(column: "mood", .text)
            }
            print("Database migration completed: 'mood' column added")
        }
        
        // Add any future migrations here
    }
    
    // MARK: - Journal Entry Operations
    
    /// Adds a new journal entry to the database with encrypted content
    /// - Parameter entry: The journal entry to save
    /// - Throws: DatabaseError or EncryptionError
    func addEntry(_ entry: JournalEntry) async throws {
        // Encrypt the content and title before storing
        let encryptedContent = try await encryptContent(entry.content)
        let encryptedTitle = try await encryptContent(entry.title)
        
        // Create encrypted entry for storage
        let encryptedEntry = JournalEntry(
            id: entry.id,
            date: entry.date,
            title: encryptedTitle,
            content: encryptedContent,
            mood: entry.mood
        )
        
        try await dbQueue.write { db in
            try encryptedEntry.insert(db)
        }
        
        print("Journal entry saved with ID: \(entry.id)")
    }
    
    /// Updates an existing journal entry in the database with encrypted content
    /// - Parameter entry: The journal entry to update
    /// - Throws: DatabaseError or EncryptionError
    func updateEntry(_ entry: JournalEntry) async throws {
        // Encrypt the content and title before storing
        let encryptedContent = try await encryptContent(entry.content)
        let encryptedTitle = try await encryptContent(entry.title)
        
        // Create encrypted entry for storage
        let encryptedEntry = JournalEntry(
            id: entry.id,
            date: entry.date,
            title: encryptedTitle,
            content: encryptedContent,
            mood: entry.mood
        )
        
        try await dbQueue.write { db in
            try encryptedEntry.update(db)
        }
        
        print("Journal entry updated with ID: \(entry.id)")
    }
    
    /// Fetches all journal entries from the database with decrypted content
    /// - Returns: A tuple containing the decrypted entries and any decryption errors
    /// - Throws: DatabaseError if database operations fail
    func fetchAllEntries() async throws -> (entries: [JournalEntry], decryptionFailures: Int) {
        let encryptedEntries = try await dbQueue.read { db in
            try JournalEntry.fetchAllOrderedByDate(db)
        }
        
        // Decrypt all entries
        var decryptedEntries: [JournalEntry] = []
        var decryptionErrors = 0
        var failedEntryIds: [UUID] = []
        
        for encryptedEntry in encryptedEntries {
            do {
                let decryptedContent = try await decryptContent(encryptedEntry.content)
                let decryptedTitle = try await decryptContent(encryptedEntry.title)
                let decryptedEntry = JournalEntry(
                    id: encryptedEntry.id,
                    date: encryptedEntry.date,
                    title: decryptedTitle,
                    content: decryptedContent,
                    mood: encryptedEntry.mood
                )
                decryptedEntries.append(decryptedEntry)
            } catch {
                decryptionErrors += 1
                failedEntryIds.append(encryptedEntry.id)
                print("❌ Failed to decrypt entry \(encryptedEntry.id): \(error)")
                
                // Include entry with error indicator but preserve metadata
                let errorEntry = JournalEntry(
                    id: encryptedEntry.id,
                    date: encryptedEntry.date,
                    title: "🔒 Encrypted Entry",
                    content: "This entry could not be decrypted. This might happen if:\n\n• The app was reinstalled\n• The encryption key was reset\n• The keychain was cleared\n\nDate: \(encryptedEntry.date.formatted(date: .complete, time: .shortened))",
                    mood: encryptedEntry.mood
                )
                decryptedEntries.append(errorEntry)
            }
        }
        
        if decryptionErrors > 0 {
            print("⚠️ Failed to decrypt \(decryptionErrors) out of \(encryptedEntries.count) entries")
            print("Failed entry IDs: \(failedEntryIds)")
        }
        
        return (decryptedEntries, decryptionErrors)
    }
    
    /// Fetches journal entries with pagination support
    /// - Parameters:
    ///   - limit: Maximum number of entries to fetch
    ///   - offset: Number of entries to skip
    /// - Returns: A tuple containing the decrypted entries and any decryption errors
    /// - Throws: DatabaseError if database operations fail
    func fetchEntries(limit: Int, offset: Int) async throws -> (entries: [JournalEntry], decryptionFailures: Int) {
        let encryptedEntries = try await dbQueue.read { db in
            try JournalEntry.fetchWithPagination(db, limit: limit, offset: offset)
        }
        
        // Decrypt all entries
        var decryptedEntries: [JournalEntry] = []
        var decryptionErrors = 0
        var failedEntryIds: [UUID] = []
        
        for encryptedEntry in encryptedEntries {
            do {
                let decryptedContent = try await decryptContent(encryptedEntry.content)
                let decryptedTitle = try await decryptContent(encryptedEntry.title)
                let decryptedEntry = JournalEntry(
                    id: encryptedEntry.id,
                    date: encryptedEntry.date,
                    title: decryptedTitle,
                    content: decryptedContent,
                    mood: encryptedEntry.mood
                )
                decryptedEntries.append(decryptedEntry)
            } catch {
                decryptionErrors += 1
                failedEntryIds.append(encryptedEntry.id)
                print("❌ Failed to decrypt entry \(encryptedEntry.id): \(error)")
                
                // Include entry with error indicator but preserve metadata
                let errorEntry = JournalEntry(
                    id: encryptedEntry.id,
                    date: encryptedEntry.date,
                    title: "🔒 Encrypted Entry",
                    content: "This entry could not be decrypted. This might happen if:\n\n• The app was reinstalled\n• The encryption key was reset\n• The keychain was cleared\n\nDate: \(encryptedEntry.date.formatted(date: .complete, time: .shortened))",
                    mood: encryptedEntry.mood
                )
                decryptedEntries.append(errorEntry)
            }
        }
        
        if decryptionErrors > 0 {
            print("⚠️ Failed to decrypt \(decryptionErrors) out of \(encryptedEntries.count) entries")
            print("Failed entry IDs: \(failedEntryIds)")
        }
        
        return (decryptedEntries, decryptionErrors)
    }
    
    /// Fetches a specific journal entry by ID with decrypted content
    /// - Parameter id: The UUID of the entry to fetch
    /// - Returns: The decrypted journal entry if found, nil otherwise
    /// - Throws: DatabaseError or DecryptionError
    func fetchEntry(id: UUID) async throws -> JournalEntry? {
        guard let encryptedEntry = try await dbQueue.read({ db in
            try JournalEntry.fetchEntry(db, id: id)
        }) else {
            return nil
        }
        
        do {
            let decryptedContent = try await decryptContent(encryptedEntry.content)
            let decryptedTitle = try await decryptContent(encryptedEntry.title)
            return JournalEntry(
                id: encryptedEntry.id,
                date: encryptedEntry.date,
                title: decryptedTitle,
                content: decryptedContent,
                mood: encryptedEntry.mood
            )
        } catch {
            print("❌ Failed to decrypt entry \(encryptedEntry.id): \(error)")
            // Return entry with placeholder content to maintain data integrity
            return JournalEntry(
                id: encryptedEntry.id,
                date: encryptedEntry.date,
                title: "[Decryption Error]",
                content: "This entry could not be decrypted. The encryption key may have changed.",
                mood: encryptedEntry.mood
            )
        }
    }
    
    /// Deletes a journal entry from the database
    /// - Parameter id: The UUID of the entry to delete
    /// - Returns: True if the entry was deleted, false if not found
    /// - Throws: DatabaseError
    func deleteEntry(id: UUID) async throws -> Bool {
        let deleted = try await dbQueue.write { db in
            try JournalEntry.filter(JournalEntry.Columns.id == id).deleteAll(db)
        }
        
        print("Journal entry \(deleted > 0 ? "deleted" : "not found"): \(id)")
        return deleted > 0
    }
    
    /// Gets the total count of journal entries
    /// - Returns: Number of entries in the database
    /// - Throws: DatabaseError
    func getEntryCount() async throws -> Int {
        return try await dbQueue.read { db in
            try JournalEntry.fetchCount(db)
        }
    }
}

// MARK: - Encryption Operations

extension DatabaseManager {
    
    /// Encrypts journal content using AES-256-GCM
    /// - Parameter content: Plain text content to encrypt
    /// - Returns: Base64-encoded encrypted content with nonce
    /// - Throws: EncryptionError
    private func encryptContent(_ content: String) async throws -> String {
        // Handle empty content gracefully
        if content.isEmpty {
            return ""
        }
        
        let key = try await getOrCreateEncryptionKey()
        let data = Data(content.utf8)
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        guard let encryptedData = sealedBox.combined else {
            throw DatabaseError.encryptionFailed
        }
        
        return encryptedData.base64EncodedString()
    }
    
    /// Decrypts journal content using AES-256-GCM
    /// - Parameter encryptedContent: Base64-encoded encrypted content
    /// - Returns: Decrypted plain text content
    /// - Throws: DecryptionError
    private func decryptContent(_ encryptedContent: String) async throws -> String {
        // Handle empty content gracefully
        if encryptedContent.isEmpty {
            return ""
        }
        
        let key = try await getOrCreateEncryptionKey()
        
        guard let encryptedData = Data(base64Encoded: encryptedContent) else {
            throw DatabaseError.invalidEncryptedData
        }
        
        // Check minimum size for AES-GCM (12 bytes nonce + at least 1 byte ciphertext + 16 bytes tag)
        guard encryptedData.count >= 29 else {
            print("❌ Encrypted data too small: \(encryptedData.count) bytes")
            throw DatabaseError.invalidEncryptedData
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw DatabaseError.decryptionFailed
        }
        
        return decryptedString
    }
}

// MARK: - Keychain Operations

extension DatabaseManager {
    
    /// Gets the encryption key from Keychain or creates a new one
    /// - Returns: AES-256 symmetric encryption key
    /// - Throws: KeychainError
    private func getOrCreateEncryptionKey() async throws -> SymmetricKey {
        // Try to get existing key from Keychain
        if let existingKeyData = try getKeyFromKeychain() {
            return SymmetricKey(data: existingKeyData)
        }
        
        // Create new key and store in Keychain
        let newKey = SymmetricKey(size: .bits256)
        try storeKeyInKeychain(newKey.withUnsafeBytes { Data($0) })
        
        print("New encryption key created and stored in Keychain")
        return newKey
    }
    
    /// Retrieves encryption key from macOS Keychain
    /// - Returns: Key data if found, nil otherwise
    /// - Throws: KeychainError
    private func getKeyFromKeychain() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw DatabaseError.keychainError(status)
        }
    }
    
    /// Stores encryption key in macOS Keychain
    /// - Parameter keyData: The encryption key data to store
    /// - Throws: KeychainError
    private func storeKeyInKeychain(_ keyData: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly // Device-specific security
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw DatabaseError.keychainError(status)
        }
    }
}

// MARK: - Utility Methods

extension DatabaseManager {
    
    /// Provides access to the database for actors like MemoryStore
    var database: DatabaseQueue {
        dbQueue
    }
    
    /// Gets the Application Support directory for storing the database
    /// - Returns: URL to the app's Application Support directory
    /// - Throws: FileSystemError if directory cannot be accessed or created
    private static func getApplicationSupportDirectory() throws -> URL {
        let fileManager = FileManager.default
        
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw DatabaseError.applicationSupportDirectoryNotFound
        }
        
        let appDirectory = applicationSupportURL.appendingPathComponent("Gemi")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            print("Created Application Support directory: \(appDirectory.path)")
        }
        
        return appDirectory
    }
}

// MARK: - Memory Management Extensions

extension DatabaseManager {
    
    /// Save a memory to the database
    func saveMemory(_ memory: Memory) async throws {
        try await dbWriter.write { db in
            try memory.save(db)
        }
    }
    
    /// Get total memory count
    func getMemoryCount() async throws -> Int {
        try await dbReader.read { db in
            try Memory.fetchCount(db)
        }
    }
    
    /// Search memories by query
    func searchMemories(query: String, limit: Int) async throws -> [Memory] {
        try await dbReader.read { db in
            let pattern = FTS5Pattern(matchingAllTokensIn: query)
            return try Memory
                .matching(pattern)
                .order(Column("importance").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
    
    /// Update memory access time
    func updateMemoryAccessTime(_ id: UUID) async throws {
        try await dbWriter.write { db in
            try db.execute(
                sql: "UPDATE memories SET lastAccessedAt = ? WHERE id = ?",
                arguments: [Date(), id]
            )
        }
    }
    
    /// Delete memories for a specific entry
    func deleteMemoriesForEntry(_ entryId: UUID) async throws {
        _ = try await dbWriter.write { db in
            try Memory
                .filter(Column("sourceEntryId") == entryId)
                .deleteAll(db)
        }
    }
    
    /// Delete orphaned memories
    func deleteOrphanedMemories() async throws -> Int {
        try await dbWriter.write { db in
            // Find memories with sourceEntryId that don't have corresponding entries
            let orphanedMemories = try Memory
                .filter(sql: """
                    sourceEntryId IS NOT NULL AND 
                    sourceEntryId NOT IN (SELECT id FROM entries)
                """)
                .fetchAll(db)
            
            // Delete them
            for memory in orphanedMemories {
                try memory.delete(db)
            }
            
            return orphanedMemories.count
        }
    }
    
    /// Delete a specific memory
    func deleteMemory(_ id: UUID) async throws {
        _ = try await dbWriter.write { db in
            try Memory.deleteOne(db, key: id)
        }
    }
    
    /// Fetch oldest memories for archiving
    func fetchOldestMemories(limit: Int) async throws -> [Memory] {
        try await dbReader.read { db in
            try Memory
                .filter(Memory.Columns.isPinned == false)
                .order(
                    Memory.Columns.importance,
                    Memory.Columns.lastAccessedAt
                )
                .limit(limit)
                .fetchAll(db)
        }
    }
    

    
    /// Get entries with embeddings count
    func getEntriesWithEmbeddingsCount() async throws -> Int {
        try await dbReader.read { db in
            let entriesWithEmbeddings = try JournalEntry
                .filter(sql: "id IN (SELECT DISTINCT sourceEntryId FROM memories WHERE sourceEntryId IS NOT NULL)")
                .fetchCount(db)
            return entriesWithEmbeddings
        }
    }
    
    /// Fetch entries without embeddings
    func fetchEntriesWithoutEmbeddings() async throws -> [JournalEntry] {
        try await dbReader.read { db in
            try JournalEntry
                .filter(sql: "id NOT IN (SELECT DISTINCT sourceEntryId FROM memories WHERE sourceEntryId IS NOT NULL)")
                .fetchAll(db)
        }
    }
    
    /// Search memories by similarity (placeholder - needs vector search implementation)
    func searchMemoriesBySimilarity(embedding: [Float], limit: Int) async throws -> [Memory] {
        // For now, return recent memories as a placeholder
        // In a real implementation, this would use vector similarity search
        try await dbReader.read { db in
            try Memory
                .order(Column("lastAccessedAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
    
    /// Fetch entry by ID
    func fetchEntry(by id: UUID) async throws -> JournalEntry? {
        try await dbReader.read { db in
            try JournalEntry.fetchOne(db, key: id)
        }
    }
    
    /// Attempts to re-encrypt an entry with a new key
    /// This can be used to recover entries after key changes
    func attemptEntryRecovery(entryId: UUID, with content: String, title: String) async throws {
        // Encrypt the content with the current key
        let encryptedContent = try await encryptContent(content)
        let encryptedTitle = try await encryptContent(title)
        
        // Update the entry in the database
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE entries SET content = ?, title = ? WHERE id = ?",
                arguments: [encryptedContent, encryptedTitle, entryId]
            )
        }
        
        print("✅ Successfully re-encrypted entry \(entryId)")
    }
    
    /// Checks if the encryption key is valid by attempting to decrypt a test value
    func validateEncryptionKey() async -> Bool {
        do {
            // Try to encrypt and decrypt a test string
            let testString = "Gemi encryption test"
            let encrypted = try await encryptContent(testString)
            let decrypted = try await decryptContent(encrypted)
            return decrypted == testString
        } catch {
            print("❌ Encryption key validation failed: \(error)")
            return false
        }
    }
    
    /// Creates a diagnostic report about the database state
    func getDatabaseDiagnostics() async throws -> DatabaseDiagnostics {
        let totalEntries = try await dbQueue.read { db in
            try JournalEntry.fetchCount(db)
        }
        
        let result = try await fetchAllEntries()
        let keyValid = await validateEncryptionKey()
        
        return DatabaseDiagnostics(
            totalEntries: totalEntries,
            readableEntries: result.entries.filter { !$0.title.contains("🔒") }.count,
            encryptedEntries: result.decryptionFailures,
            encryptionKeyValid: keyValid,
            databasePath: dbQueue.path
        )
    }
}

// MARK: - Error Types

/// Errors that can occur during database operations
enum DatabaseError: Error, LocalizedError {
    case applicationSupportDirectoryNotFound
    case invalidEncryptedData
    case decryptionFailed
    case encryptionFailed
    case keychainError(OSStatus)
    case initializationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryNotFound:
            return "Could not access Application Support directory"
        case .invalidEncryptedData:
            return "Invalid encrypted data format"
        case .decryptionFailed:
            return "Failed to decrypt journal content"
        case .encryptionFailed:
            return "Failed to encrypt journal content"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .initializationFailed(let message):
            return message
        }
    }
}

/// Database diagnostic information
struct DatabaseDiagnostics {
    let totalEntries: Int
    let readableEntries: Int
    let encryptedEntries: Int
    let encryptionKeyValid: Bool
    let databasePath: String
    
    var summary: String {
        """
        Database Diagnostics:
        • Total entries: \(totalEntries)
        • Readable entries: \(readableEntries)
        • Encrypted/unreadable entries: \(encryptedEntries)
        • Encryption key valid: \(encryptionKeyValid ? "Yes" : "No")
        • Database location: \(databasePath)
        """
    }
} 