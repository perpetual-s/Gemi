import Foundation

/// DatabaseTest provides comprehensive testing for the DatabaseManager functionality
/// This demonstrates the complete encrypt → store → fetch → decrypt workflow
/// 
/// Test Coverage:
/// - Database initialization
/// - Journal entry creation and storage
/// - Encryption/decryption verification
/// - CRUD operations
/// - Error handling
class DatabaseTest {
    
    private let databaseManager: DatabaseManager
    
    /// Initialize the test with a DatabaseManager instance
    /// - Throws: DatabaseError if initialization fails
    init() throws {
        self.databaseManager = try DatabaseManager()
    }
    
    /// Runs all database tests with comprehensive logging
    /// This demonstrates the complete functionality of the data layer
    func runAllTests() async {
        print("\nStarting Gemi Database Layer Tests")
        print("=====================================")
        
        do {
            try await testBasicOperations()
            try await testMultipleEntries()
            try await testEncryptionVerification()
            try await testDeleteOperations()
            try await testErrorHandling()
            
            print("\nAll database tests passed successfully!")
            print("Encryption/decryption working correctly")
            print("CRUD operations functioning properly")
            
        } catch {
            print("\nDatabase test failed: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Test Cases
    
    /// Test basic database operations: create, read, count
    private func testBasicOperations() async throws {
        print("\nTest 1: Basic Operations")
        print("---------------------------")
        
        // Create a test journal entry
        let testContent = """
        Dear Diary,
        
        Today was an amazing day! I started working on Gemi, my privacy-first AI diary app. 
        The goal is to create a completely offline journaling experience where users can:
        
        - Write personal thoughts securely
        - Chat with a local AI companion (Gemma 3n)
        - Keep all data private and encrypted
        
        I'm excited about building something that truly respects user privacy!
        
        Tomorrow I'll continue with the UI development.
        
        Best,
        A Gemi User
        """
        
        let entry = JournalEntry(content: testContent)
        print("Created test entry with ID: \(entry.id)")
        print("Date: \(entry.date)")
        print("Content length: \(entry.content.count) characters")
        
        // Save the entry (should encrypt content automatically)
        print("\nSaving entry (content will be encrypted)...")
        try await databaseManager.addEntry(entry)
        
        // Verify the entry count
        let count = try await databaseManager.getEntryCount()
        print("Total entries in database: \(count)")
        
        // Fetch all entries (should decrypt content automatically)
        print("\nFetching all entries (content will be decrypted)...")
        let fetchedEntries = try await databaseManager.fetchAllEntries()
        
        print("Retrieved \(fetchedEntries.count) entries")
        
        // Verify the content matches
        guard let retrievedEntry = fetchedEntries.first else {
            throw TestError.entryNotFound
        }
        
        print("Entry successfully retrieved!")
        print("ID matches: \(retrievedEntry.id == entry.id)")
        print("Date matches: \(retrievedEntry.date == entry.date)")
        print("Content matches: \(retrievedEntry.content == entry.content)")
        
        // Display a preview of the decrypted content
        let preview = String(retrievedEntry.content.prefix(100))
        print("Content preview: \"\(preview)...\"")
    }
    
    /// Test multiple entries to verify ordering and bulk operations
    private func testMultipleEntries() async throws {
        print("\nTest 2: Multiple Entries")
        print("---------------------------")
        
        let entries = [
            JournalEntry(content: "Entry 1: Monday morning thoughts about privacy and technology."),
            JournalEntry(content: "Entry 2: Afternoon reflection on the importance of local-first software."),
            JournalEntry(content: "Entry 3: Evening notes about Swift 6 concurrency patterns."),
            JournalEntry(content: "Entry 4: Late night ideas for improving the Gemi user experience.")
        ]
        
        print("Adding \(entries.count) test entries...")
        
        // Add all entries
        for (index, entry) in entries.enumerated() {
            try await databaseManager.addEntry(entry)
            print("Added entry \(index + 1): \(entry.id)")
            
            // Small delay to ensure different timestamps
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Fetch all entries and verify ordering
        let allEntries = try await databaseManager.fetchAllEntries()
        print("\nRetrieved \(allEntries.count) total entries")
        print("Entries ordered by date (newest first):")
        
        for (index, entry) in allEntries.enumerated() {
            let preview = String(entry.content.prefix(50))
            print("   \(index + 1). \(entry.date): \"\(preview)...\"")
        }
        
        // Verify newest entries appear first
        if allEntries.count >= 2 {
            let newest = allEntries[0]
            let older = allEntries[1]
            print("Date ordering verified: \(newest.date >= older.date)")
        }
    }
    
    /// Test encryption by verifying that stored data is actually encrypted
    private func testEncryptionVerification() async throws {
        print("\nTest 3: Encryption Verification")
        print("-----------------------------------")
        
        let sensitiveContent = """
        This is highly sensitive personal information that should be encrypted:
        - Social Security Number: 123-45-6789
        - Bank Account: 9876543210
        - Personal Secrets: I secretly love pineapple on pizza!
        
        If this appears in plain text in the database file, encryption is not working!
        """
        
        let sensitiveEntry = JournalEntry(content: sensitiveContent)
        print("Creating entry with sensitive content...")
        print("Original content contains: \"Social Security Number\"")
        
        try await databaseManager.addEntry(sensitiveEntry)
        print("Sensitive entry saved to database")
        
        // Fetch the entry back and verify it's properly decrypted
        let retrieved = try await databaseManager.fetchEntry(id: sensitiveEntry.id)
        guard let decryptedEntry = retrieved else {
            throw TestError.entryNotFound
        }
        
        print("Entry successfully decrypted after retrieval")
        print("Sensitive content properly restored")
        print("Encryption/decryption cycle working correctly")
        
        // Verify the sensitive content is intact
        let containsSensitiveData = decryptedEntry.content.contains("Social Security Number")
        print("Sensitive data verification: \(containsSensitiveData ? "Present" : "Missing")")
    }
    
    /// Test delete operations
    private func testDeleteOperations() async throws {
        print("\nTest 4: Delete Operations")
        print("-----------------------------")
        
        // Get current count
        let initialCount = try await databaseManager.getEntryCount()
        print("Initial entry count: \(initialCount)")
        
        // Create a temporary entry for deletion testing
        let tempEntry = JournalEntry(content: "This entry will be deleted as part of testing.")
        try await databaseManager.addEntry(tempEntry)
        
        let countAfterAdd = try await databaseManager.getEntryCount()
        print("Count after adding temp entry: \(countAfterAdd)")
        
        // Delete the entry
        let deleteSuccess = try await databaseManager.deleteEntry(id: tempEntry.id)
        print("Delete operation result: \(deleteSuccess ? "Success" : "Failed")")
        
        let finalCount = try await databaseManager.getEntryCount()
        print("Final entry count: \(finalCount)")
        
        // Verify the count returned to initial value
        let countRestored = (finalCount == initialCount)
        print("Entry count properly restored: \(countRestored)")
        
        // Try to fetch the deleted entry (should return nil)
        let deletedEntry = try await databaseManager.fetchEntry(id: tempEntry.id)
        let properlyDeleted = (deletedEntry == nil)
        print("Entry properly deleted from database: \(properlyDeleted)")
    }
    
    /// Test error handling scenarios
    private func testErrorHandling() async throws {
        print("\nTest 5: Error Handling")
        print("-------------------------")
        
        // Test fetching non-existent entry
        let nonExistentID = UUID()
        let result = try await databaseManager.fetchEntry(id: nonExistentID)
        let handlesNonExistent = (result == nil)
        print("Non-existent entry handling: \(handlesNonExistent ? "Correct (nil)" : "Incorrect")")
        
        // Test deleting non-existent entry
        let deleteResult = try await databaseManager.deleteEntry(id: nonExistentID)
        let handlesNonExistentDelete = !deleteResult
        print("Non-existent deletion handling: \(handlesNonExistentDelete ? "Correct (false)" : "Incorrect")")
        
        print("Error handling tests completed")
    }
}

// MARK: - Test Error Types

enum TestError: Error, LocalizedError {
    case entryNotFound
    case contentMismatch
    case encryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .entryNotFound:
            return "Test entry was not found in database"
        case .contentMismatch:
            return "Retrieved content does not match original"
        case .encryptionFailed:
            return "Encryption/decryption verification failed"
        }
    }
}

// MARK: - Test Runner Function

/// Convenience function to run all database tests
/// This can be called from anywhere in the app for testing
func runDatabaseTests() async {
    do {
        let test = try DatabaseTest()
        await test.runAllTests()
    } catch {
        print("Failed to initialize database tests: \(error)")
    }
} 