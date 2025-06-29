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
    
    // MARK: - Properties
    
    /// The GRDB database queue for thread-safe operations
    private let dbQueue: DatabaseQueue
    
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
        
        // Create tables in a separate transaction
        try dbQueue.write { db in
            // Create the journal entries table
            try JournalEntry.createTable(db)
            
            print("Database schema initialized")
        }
    }
    
    // MARK: - Journal Entry Operations
    
    /// Adds a new journal entry to the database with encrypted content
    /// - Parameter entry: The journal entry to save
    /// - Throws: DatabaseError or EncryptionError
    func addEntry(_ entry: JournalEntry) async throws {
        // Encrypt the content before storing
        let encryptedContent = try await encryptContent(entry.content)
        
        // Create encrypted entry for storage
        let encryptedEntry = JournalEntry(
            id: entry.id,
            date: entry.date,
            content: encryptedContent
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
        // Encrypt the content before storing
        let encryptedContent = try await encryptContent(entry.content)
        
        // Create encrypted entry for storage
        let encryptedEntry = JournalEntry(
            id: entry.id,
            date: entry.date,
            content: encryptedContent
        )
        
        try await dbQueue.write { db in
            try encryptedEntry.update(db)
        }
        
        print("Journal entry updated with ID: \(entry.id)")
    }
    
    /// Fetches all journal entries from the database with decrypted content
    /// - Returns: Array of decrypted journal entries, ordered by date (newest first)
    /// - Throws: DatabaseError or DecryptionError
    func fetchAllEntries() async throws -> [JournalEntry] {
        let encryptedEntries = try await dbQueue.read { db in
            try JournalEntry.fetchAllOrderedByDate(db)
        }
        
        // Decrypt all entries
        var decryptedEntries: [JournalEntry] = []
        for encryptedEntry in encryptedEntries {
            let decryptedContent = try await decryptContent(encryptedEntry.content)
            let decryptedEntry = JournalEntry(
                id: encryptedEntry.id,
                date: encryptedEntry.date,
                content: decryptedContent
            )
            decryptedEntries.append(decryptedEntry)
        }
        
        return decryptedEntries
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
        
        let decryptedContent = try await decryptContent(encryptedEntry.content)
        return JournalEntry(
            id: encryptedEntry.id,
            date: encryptedEntry.date,
            content: decryptedContent
        )
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
        let key = try await getOrCreateEncryptionKey()
        let data = Data(content.utf8)
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        let encryptedData = sealedBox.combined!
        
        return encryptedData.base64EncodedString()
    }
    
    /// Decrypts journal content using AES-256-GCM
    /// - Parameter encryptedContent: Base64-encoded encrypted content
    /// - Returns: Decrypted plain text content
    /// - Throws: DecryptionError
    private func decryptContent(_ encryptedContent: String) async throws -> String {
        let key = try await getOrCreateEncryptionKey()
        
        guard let encryptedData = Data(base64Encoded: encryptedContent) else {
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

// MARK: - Error Types

/// Errors that can occur during database operations
enum DatabaseError: Error, LocalizedError {
    case applicationSupportDirectoryNotFound
    case invalidEncryptedData
    case decryptionFailed
    case keychainError(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryNotFound:
            return "Could not access Application Support directory"
        case .invalidEncryptedData:
            return "Invalid encrypted data format"
        case .decryptionFailed:
            return "Failed to decrypt journal content"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        }
    }
} 