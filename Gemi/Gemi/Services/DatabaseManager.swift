import Foundation
import SQLite3
import CryptoKit
import Security

final class DatabaseManager: @unchecked Sendable {
    static let shared = DatabaseManager()
    
    private let databaseName = "gemi.db"
    private let encryptionKeyTag = "com.gemi.encryptionKey"
    private var database: OpaquePointer?
    private let queue = DispatchQueue(label: "com.gemi.database", attributes: .concurrent)
    
    private init() {}
    
    func initialize() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                do {
                    try self.setupDatabase()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
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
        
        try FileManager.default.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let databaseURL = appDirectory.appendingPathComponent(databaseName)
        
        print("Database path: \(databaseURL.path)")
        
        if sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(database))
            print("Failed to open database: \(errorMessage)")
            throw DatabaseError.failedToOpen
        }
        
        // Enable Write-Ahead Logging for better performance
        try executeSQL("PRAGMA journal_mode=WAL")
        
        try createTables()
    }
    
    private func createTables() throws {
        let createEntriesTable = """
            CREATE TABLE IF NOT EXISTS journal_entries (
                id TEXT PRIMARY KEY NOT NULL,
                created_at REAL NOT NULL,
                modified_at REAL NOT NULL,
                title TEXT,
                content TEXT,
                encrypted_content BLOB,
                tags TEXT,
                mood TEXT,
                weather TEXT,
                location TEXT,
                attachments TEXT,
                is_encrypted INTEGER NOT NULL DEFAULT 1,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                is_deleted INTEGER NOT NULL DEFAULT 0
            )
        """
        
        let createUsersTable = """
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                email TEXT,
                created_at REAL NOT NULL,
                last_login_at REAL NOT NULL,
                preferences BLOB
            )
        """
        
        let createIndices = [
            "CREATE INDEX IF NOT EXISTS idx_entries_created_at ON journal_entries(created_at)",
            "CREATE INDEX IF NOT EXISTS idx_entries_is_deleted ON journal_entries(is_deleted)",
            "CREATE INDEX IF NOT EXISTS idx_entries_is_favorite ON journal_entries(is_favorite)"
        ]
        
        try executeSQL(createEntriesTable)
        try executeSQL(createUsersTable)
        
        for index in createIndices {
            try executeSQL(index)
        }
    }
    
    private func executeSQL(_ sql: String) throws {
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToPrepare(sql)
        }
        
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.failedToExecute(sql)
        }
    }
    
    // MARK: - Encryption
    
    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        if let existingKey = try? loadEncryptionKey() {
            return existingKey
        }
        
        let key = SymmetricKey(size: .bits256)
        try saveEncryptionKey(key)
        return key
    }
    
    private func saveEncryptionKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: encryptionKeyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw DatabaseError.failedToSaveKey
        }
    }
    
    private func loadEncryptionKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: encryptionKeyTag,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let keyData = item as? Data else {
            throw DatabaseError.keyNotFound
        }
        
        return SymmetricKey(data: keyData)
    }
    
    private func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        return sealedBox.combined ?? Data()
    }
    
    private func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - Journal Entry Operations
    
    func saveEntry(_ entry: JournalEntry) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                do {
                    try self.saveEntrySync(entry)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func saveEntrySync(_ entry: JournalEntry) throws {
        let sql = """
            INSERT OR REPLACE INTO journal_entries 
            (id, created_at, modified_at, title, content, encrypted_content, tags, mood, weather, location, attachments, is_encrypted, is_favorite, is_deleted)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToPrepare(sql)
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, entry.id.uuidString, -1, nil)
        sqlite3_bind_double(statement, 2, entry.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 3, entry.modifiedAt.timeIntervalSince1970)
        sqlite3_bind_text(statement, 4, entry.title, -1, nil)
        
        // Handle content and encrypted content properly
        if entry.isEncrypted, let encryptedData = entry.encryptedContent {
            // Entry is already encrypted, store the encrypted data
            sqlite3_bind_null(statement, 5) // content is null
            sqlite3_bind_blob(statement, 6, [UInt8](encryptedData), Int32(encryptedData.count), nil)
        } else if entry.isEncrypted && !entry.content.isEmpty {
            // Entry needs to be encrypted
            let contentData = entry.content.data(using: .utf8) ?? Data()
            let encryptedData = try encrypt(contentData)
            sqlite3_bind_null(statement, 5) // content is null
            sqlite3_bind_blob(statement, 6, [UInt8](encryptedData), Int32(encryptedData.count), nil)
        } else {
            // Entry is not encrypted
            sqlite3_bind_text(statement, 5, entry.content, -1, nil)
            sqlite3_bind_null(statement, 6)
        }
        
        let tagsJson = try JSONEncoder().encode(entry.tags)
        sqlite3_bind_text(statement, 7, String(data: tagsJson, encoding: .utf8), -1, nil)
        
        if let mood = entry.mood {
            sqlite3_bind_text(statement, 8, mood.rawValue, -1, nil)
        } else {
            sqlite3_bind_null(statement, 8)
        }
        
        if let weather = entry.weather {
            sqlite3_bind_text(statement, 9, weather, -1, nil)
        } else {
            sqlite3_bind_null(statement, 9)
        }
        
        if let location = entry.location {
            sqlite3_bind_text(statement, 10, location, -1, nil)
        } else {
            sqlite3_bind_null(statement, 10)
        }
        
        let attachmentsJson = try JSONEncoder().encode(entry.attachments)
        sqlite3_bind_text(statement, 11, String(data: attachmentsJson, encoding: .utf8), -1, nil)
        
        sqlite3_bind_int(statement, 12, entry.isEncrypted ? 1 : 0)
        sqlite3_bind_int(statement, 13, entry.isFavorite ? 1 : 0)
        sqlite3_bind_int(statement, 14, entry.isDeleted ? 1 : 0)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.failedToExecute(sql)
        }
    }
    
    func loadEntries(includeDeleted: Bool = false) async throws -> [JournalEntry] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let entries = try self.loadEntriesSync(includeDeleted: includeDeleted)
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func loadEntriesSync(includeDeleted: Bool = false) throws -> [JournalEntry] {
        let sql = includeDeleted
            ? "SELECT * FROM journal_entries ORDER BY created_at DESC"
            : "SELECT * FROM journal_entries WHERE is_deleted = 0 ORDER BY created_at DESC"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.failedToPrepare(sql)
        }
        
        defer { sqlite3_finalize(statement) }
        
        var entries: [JournalEntry] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let entry = try parseEntry(from: statement)
            entries.append(entry)
        }
        
        return entries
    }
    
    private func parseEntry(from statement: OpaquePointer?) throws -> JournalEntry {
        // Column indices based on CREATE TABLE structure:
        // 0: id, 1: created_at, 2: modified_at, 3: title, 4: content
        // 5: encrypted_content, 6: tags, 7: mood, 8: weather, 9: location
        // 10: attachments, 11: is_encrypted, 12: is_favorite, 13: is_deleted
        
        let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))) ?? UUID()
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
        let modifiedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
        
        let title = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
        
        let isEncrypted = sqlite3_column_int(statement, 11) == 1
        var content = ""
        var encryptedContent: Data? = nil
        
        if isEncrypted {
            // For encrypted entries, store the encrypted data
            if let encryptedBlob = sqlite3_column_blob(statement, 5) {
                let encryptedSize = Int(sqlite3_column_bytes(statement, 5))
                encryptedContent = Data(bytes: encryptedBlob, count: encryptedSize)
                // Leave content empty for encrypted entries
                content = ""
            }
        } else {
            // For non-encrypted entries, get the plain content
            content = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? ""
        }
        
        let tagsJson = sqlite3_column_text(statement, 6).map { String(cString: $0) } ?? "[]"
        let tags = (try? JSONDecoder().decode([String].self, from: tagsJson.data(using: .utf8) ?? Data())) ?? []
        
        let moodString = sqlite3_column_text(statement, 7).map { String(cString: $0) }
        let mood = moodString.flatMap { Mood(rawValue: $0) }
        let weather = sqlite3_column_text(statement, 8).map { String(cString: $0) }
        let location = sqlite3_column_text(statement, 9).map { String(cString: $0) }
        
        let attachmentsJson = sqlite3_column_text(statement, 10).map { String(cString: $0) } ?? "[]"
        let attachments = (try? JSONDecoder().decode([String].self, from: attachmentsJson.data(using: .utf8) ?? Data())) ?? []
        
        let isFavorite = sqlite3_column_int(statement, 12) == 1
        let isDeleted = sqlite3_column_int(statement, 13) == 1
        
        return JournalEntry(
            id: id,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            title: title,
            content: content,
            encryptedContent: encryptedContent,
            tags: tags,
            mood: mood,
            weather: weather,
            location: location,
            attachments: attachments,
            isEncrypted: isEncrypted,
            isFavorite: isFavorite,
            isDeleted: isDeleted
        )
    }
    
    func deleteEntry(_ id: UUID, permanently: Bool = false) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                do {
                    if permanently {
                        let sql = "DELETE FROM journal_entries WHERE id = ?"
                        var statement: OpaquePointer?
                        guard sqlite3_prepare_v2(self.database, sql, -1, &statement, nil) == SQLITE_OK else {
                            throw DatabaseError.failedToPrepare(sql)
                        }
                        defer { sqlite3_finalize(statement) }
                        
                        sqlite3_bind_text(statement, 1, id.uuidString, -1, nil)
                        
                        guard sqlite3_step(statement) == SQLITE_DONE else {
                            throw DatabaseError.failedToExecute(sql)
                        }
                    } else {
                        let sql = "UPDATE journal_entries SET is_deleted = 1 WHERE id = ?"
                        var statement: OpaquePointer?
                        guard sqlite3_prepare_v2(self.database, sql, -1, &statement, nil) == SQLITE_OK else {
                            throw DatabaseError.failedToPrepare(sql)
                        }
                        defer { sqlite3_finalize(statement) }
                        
                        sqlite3_bind_text(statement, 1, id.uuidString, -1, nil)
                        
                        guard sqlite3_step(statement) == SQLITE_DONE else {
                            throw DatabaseError.failedToExecute(sql)
                        }
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func searchEntries(query: String) async throws -> [JournalEntry] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let sql = """
                        SELECT * FROM journal_entries 
                        WHERE is_deleted = 0 AND (
                            title LIKE ? OR 
                            content LIKE ? OR 
                            tags LIKE ? OR
                            mood LIKE ? OR
                            location LIKE ?
                        )
                        ORDER BY created_at DESC
                    """
                    
                    var statement: OpaquePointer?
                    guard sqlite3_prepare_v2(self.database, sql, -1, &statement, nil) == SQLITE_OK else {
                        throw DatabaseError.failedToPrepare(sql)
                    }
                    
                    defer { sqlite3_finalize(statement) }
                    
                    let searchPattern = "%\(query)%"
                    for i in 1...5 {
                        sqlite3_bind_text(statement, Int32(i), searchPattern, -1, nil)
                    }
                    
                    var entries: [JournalEntry] = []
                    
                    while sqlite3_step(statement) == SQLITE_ROW {
                        let entry = try self.parseEntry(from: statement)
                        entries.append(entry)
                    }
                    
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum DatabaseError: LocalizedError {
    case failedToOpen
    case failedToPrepare(String)
    case failedToExecute(String)
    case failedToSaveKey
    case keyNotFound
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .failedToOpen:
            return "Failed to open database"
        case .failedToPrepare(let sql):
            return "Failed to prepare SQL: \(sql)"
        case .failedToExecute(let sql):
            return "Failed to execute SQL: \(sql)"
        case .failedToSaveKey:
            return "Failed to save encryption key"
        case .keyNotFound:
            return "Encryption key not found"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        }
    }
}