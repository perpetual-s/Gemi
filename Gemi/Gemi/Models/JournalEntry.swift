import Foundation
import CryptoKit

// MARK: - Mood Enum
enum Mood: String, Codable, CaseIterable, Sendable {
    case happy = "happy"
    case sad = "sad"
    case neutral = "neutral"
    case excited = "excited"
    case anxious = "anxious"
    case peaceful = "peaceful"
    case grateful = "grateful"
    case accomplished = "accomplished"
    case frustrated = "frustrated"
    case angry = "angry"
    
    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .sad: return "😢"
        case .neutral: return "😐"
        case .excited: return "🎉"
        case .anxious: return "😰"
        case .peaceful: return "😌"
        case .grateful: return "🙏"
        case .accomplished: return "💪"
        case .frustrated: return "😤"
        case .angry: return "😡"
        }
    }
}

final class JournalEntry: Identifiable, Codable, Hashable, @unchecked Sendable {
    let id: UUID
    let createdAt: Date
    var modifiedAt: Date
    var title: String
    var content: String
    var encryptedContent: Data? // Store encrypted content separately
    var tags: [String]
    var mood: Mood?
    var weather: String?
    var location: String?
    var attachments: [String]
    var isEncrypted: Bool
    var isFavorite: Bool
    var isDeleted: Bool
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        title: String = "",
        content: String = "",
        encryptedContent: Data? = nil,
        tags: [String] = [],
        mood: Mood? = nil,
        weather: String? = nil,
        location: String? = nil,
        attachments: [String] = [],
        isEncrypted: Bool = false,
        isFavorite: Bool = false,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.title = title
        self.content = content
        self.encryptedContent = encryptedContent
        self.tags = tags
        self.mood = mood
        self.weather = weather
        self.location = location
        self.attachments = attachments
        self.isEncrypted = isEncrypted
        self.isFavorite = isFavorite
        self.isDeleted = isDeleted
    }
    
    nonisolated static func == (lhs: JournalEntry, rhs: JournalEntry) -> Bool {
        lhs.id == rhs.id
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var displayTitle: String {
        if !title.isEmpty {
            return title
        } else if !content.isEmpty {
            let firstLine = content.components(separatedBy: .newlines).first ?? ""
            return String(firstLine.prefix(50))
        } else {
            return "Untitled Entry"
        }
    }
    
    var preview: String {
        let stripped = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(stripped.prefix(200))
    }
    
    var wordCount: Int {
        content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    
    var readingTime: Int {
        max(1, wordCount / 200)
    }
    
    // MARK: - Encryption Methods
    
    /// Encrypts the content and stores it in encryptedContent
    func encrypt(using key: SymmetricKey) throws {
        guard !content.isEmpty else { return }
        
        let data = Data(content.utf8)
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        // Store encrypted content and clear plain content
        self.encryptedContent = sealedBox.combined
        self.content = "" // Clear plain text content
        self.isEncrypted = true
    }
    
    /// Decrypts the encryptedContent and returns the plain text
    func decrypt(using key: SymmetricKey) throws -> String {
        guard let encryptedData = encryptedContent else {
            return content // Return plain content if no encrypted data
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw CryptoKitError.authenticationFailure
        }
        
        return decryptedString
    }
    
    /// Returns the decrypted content for display (handles both encrypted and plain entries)
    func getDisplayContent(using key: SymmetricKey?) -> String {
        if isEncrypted, let key = key {
            return (try? decrypt(using: key)) ?? "[Unable to decrypt content]"
        }
        return content
    }
}

extension JournalEntry {
    static var preview: JournalEntry {
        JournalEntry(
            title: "Sample Entry",
            content: "This is a sample journal entry for preview purposes.",
            tags: ["sample", "preview"],
            mood: .happy
        )
    }
    
    static func mockEntries() -> [JournalEntry] {
        [
            JournalEntry(
                createdAt: Date().addingTimeInterval(-86400 * 2),
                title: "Weekend Reflections",
                content: "Had a wonderful weekend hiking in the mountains. The fresh air and scenic views were exactly what I needed to clear my mind.",
                tags: ["outdoors", "hiking", "reflection"],
                mood: .peaceful
            ),
            JournalEntry(
                createdAt: Date().addingTimeInterval(-86400),
                title: "Project Milestone",
                content: "Finally completed the major feature I've been working on. It feels great to see months of hard work come together.",
                tags: ["work", "achievement"],
                mood: .accomplished
            ),
            JournalEntry(
                createdAt: Date(),
                title: "Morning Thoughts",
                content: "Starting the day with gratitude. Sometimes it's the small things that make the biggest difference.",
                tags: ["gratitude", "morning"],
                mood: .grateful
            )
        ]
    }
}