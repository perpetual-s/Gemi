//
//  CommandRegistry.swift
//  Gemi
//

import SwiftUI

/// Represents a command that can be executed from the command palette
struct Command: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String
    let category: CommandCategory
    let shortcut: String?
    let action: () -> Void
    
    /// Aliases for better search matching
    let aliases: [String]
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        category: CommandCategory,
        shortcut: String? = nil,
        aliases: [String] = [],
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.category = category
        self.shortcut = shortcut
        self.aliases = aliases
        self.action = action
    }
}

enum CommandCategory: String, CaseIterable {
    case navigation = "Navigation"
    case entry = "Journal Entry"
    case ai = "AI Assistant"
    case settings = "Settings"
    case data = "Data Management"
    
    var icon: String {
        switch self {
        case .navigation: return "arrow.triangle.turn.up.right.diamond"
        case .entry: return "book.closed"
        case .ai: return "sparkles"
        case .settings: return "gear"
        case .data: return "externaldrive"
        }
    }
}

@MainActor
class CommandRegistry: ObservableObject {
    static let shared = CommandRegistry()
    @Published private(set) var commands: [Command] = []
    
    private init() {
        registerCommands()
    }
    
    private func registerCommands() {
        commands = [
            // Navigation Commands
            Command(
                title: "Go to Timeline",
                subtitle: "View all journal entries",
                icon: "calendar",
                category: .navigation,
                shortcut: "⌘1",
                aliases: ["home", "entries", "list", "all"],
                action: { NotificationCenter.default.post(name: .navigateToTimeline, object: nil) }
            ),
            Command(
                title: "Search Entries",
                subtitle: "Find journal entries",
                icon: "magnifyingglass",
                category: .navigation,
                shortcut: "⌘F",
                aliases: ["find", "lookup", "query"],
                action: { NotificationCenter.default.post(name: .search, object: nil) }
            ),
            Command(
                title: "View Favorites",
                subtitle: "See your starred entries",
                icon: "star",
                category: .navigation,
                shortcut: "⌘3",
                aliases: ["starred", "bookmarks", "saved"],
                action: { NotificationCenter.default.post(name: .navigateToFavorites, object: nil) }
            ),
            Command(
                title: "Memory Panel",
                subtitle: "Manage AI memories",
                icon: "brain",
                category: .navigation,
                shortcut: "⌘4",
                aliases: ["memories", "context", "knowledge"],
                action: { NotificationCenter.default.post(name: .navigateToMemories, object: nil) }
            ),
            Command(
                title: "Insights Dashboard",
                subtitle: "View patterns and analytics",
                icon: "chart.line.uptrend.xyaxis",
                category: .navigation,
                shortcut: "⌘5",
                aliases: ["analytics", "stats", "trends", "dashboard"],
                action: { NotificationCenter.default.post(name: .navigateToInsights, object: nil) }
            ),
            
            // Entry Commands
            Command(
                title: "New Entry",
                subtitle: "Create a new journal entry",
                icon: "square.and.pencil",
                category: .entry,
                shortcut: "⌘N",
                aliases: ["write", "create", "compose", "new"],
                action: { NotificationCenter.default.post(name: .newEntry, object: nil) }
            ),
            Command(
                title: "New Entry with Prompt",
                subtitle: "Start with an AI-generated prompt",
                icon: "lightbulb",
                category: .entry,
                aliases: ["prompt", "inspiration", "idea"],
                action: { 
                    NotificationCenter.default.post(name: .newEntry, object: nil, userInfo: ["withPrompt": true])
                }
            ),
            Command(
                title: "Quick Note",
                subtitle: "Capture a quick thought",
                icon: "note.text",
                category: .entry,
                aliases: ["quick", "note", "thought"],
                action: { 
                    NotificationCenter.default.post(name: .newEntry, object: nil, userInfo: ["quickNote": true])
                }
            ),
            
            // AI Commands
            Command(
                title: "Chat with Gemi",
                subtitle: "Have a conversation with AI",
                icon: "message",
                category: .ai,
                shortcut: "⌘T",
                aliases: ["talk", "chat", "ai", "gemi", "assistant"],
                action: { NotificationCenter.default.post(name: .openChat, object: nil) }
            ),
            Command(
                title: "Ask About Today",
                subtitle: "Get AI insights about today's entry",
                icon: "sun.max",
                category: .ai,
                aliases: ["today", "reflection", "daily"],
                action: { 
                    NotificationCenter.default.post(name: .openChat, object: nil, userInfo: ["prompt": "What patterns do you notice in my recent entries?"])
                }
            ),
            Command(
                title: "Generate Writing Prompt",
                subtitle: "Get inspiration for writing",
                icon: "wand.and.rays",
                category: .ai,
                aliases: ["inspire", "suggest", "help"],
                action: {
                    NotificationCenter.default.post(name: .generateWritingPrompt, object: nil)
                }
            ),
            
            // Settings Commands
            Command(
                title: "Settings",
                subtitle: "Configure Gemi",
                icon: "gear",
                category: .settings,
                shortcut: "⌘,",
                aliases: ["preferences", "config", "options"],
                action: { NotificationCenter.default.post(name: Notification.Name("ShowSettings"), object: nil) }
            ),
            Command(
                title: "Security Settings",
                subtitle: "Manage authentication and encryption",
                icon: "lock",
                category: .settings,
                aliases: ["privacy", "security", "auth", "password"],
                action: { 
                    NotificationCenter.default.post(name: Notification.Name("ShowSettings"), object: nil, userInfo: ["tab": "security"])
                }
            ),
            Command(
                title: "AI Model Settings",
                subtitle: "Configure Gemma 3n settings",
                icon: "cpu",
                category: .settings,
                aliases: ["model", "llm", "gemma"],
                action: { 
                    NotificationCenter.default.post(name: Notification.Name("ShowSettings"), object: nil, userInfo: ["tab": "ai"])
                }
            ),
            Command(
                title: "Lock Gemi",
                subtitle: "Sign out and lock the app",
                icon: "lock.circle",
                category: .settings,
                shortcut: "⌘⌃L",
                aliases: ["logout", "signout", "lock"],
                action: { NotificationCenter.default.post(name: .lockGemi, object: nil) }
            ),
            
            // Data Management Commands
            Command(
                title: "Export Entries",
                subtitle: "Export journal to various formats",
                icon: "square.and.arrow.up",
                category: .data,
                aliases: ["export", "backup", "save"],
                action: { NotificationCenter.default.post(name: .showExport, object: nil) }
            ),
            Command(
                title: "Import Entries",
                subtitle: "Import from another journal app",
                icon: "square.and.arrow.down",
                category: .data,
                aliases: ["import", "restore", "load"],
                action: { NotificationCenter.default.post(name: .showImport, object: nil) }
            ),
            Command(
                title: "Clear All Memories",
                subtitle: "Delete all AI memories",
                icon: "trash",
                category: .data,
                aliases: ["delete", "clear", "reset", "wipe"],
                action: { NotificationCenter.default.post(name: .clearMemories, object: nil) }
            ),
            Command(
                title: "Backup to Disk",
                subtitle: "Create encrypted backup",
                icon: "externaldrive.badge.plus",
                category: .data,
                aliases: ["backup", "save", "archive"],
                action: { NotificationCenter.default.post(name: .createBackup, object: nil) }
            )
        ]
    }
    
    /// Search commands using fuzzy matching
    func search(_ query: String) -> [Command] {
        guard !query.isEmpty else { return commands }
        
        let lowercasedQuery = query.lowercased()
        
        return commands.filter { command in
            // Exact match in title
            if command.title.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            // Match in subtitle
            if let subtitle = command.subtitle,
               subtitle.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            // Match in aliases
            if command.aliases.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
                return true
            }
            
            // Match in category
            if command.category.rawValue.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            // Fuzzy match on title
            return fuzzyMatch(query: lowercasedQuery, in: command.title.lowercased())
        }.sorted { first, second in
            // Prioritize exact title matches
            let firstTitleMatch = first.title.lowercased().hasPrefix(lowercasedQuery)
            let secondTitleMatch = second.title.lowercased().hasPrefix(lowercasedQuery)
            
            if firstTitleMatch != secondTitleMatch {
                return firstTitleMatch
            }
            
            // Then sort by title length (shorter = more relevant)
            return first.title.count < second.title.count
        }
    }
    
    /// Simple fuzzy matching algorithm
    private func fuzzyMatch(query: String, in text: String) -> Bool {
        var queryIndex = query.startIndex
        var textIndex = text.startIndex
        
        while queryIndex < query.endIndex && textIndex < text.endIndex {
            if query[queryIndex] == text[textIndex] {
                queryIndex = query.index(after: queryIndex)
            }
            textIndex = text.index(after: textIndex)
        }
        
        return queryIndex == query.endIndex
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let navigateToTimeline = Notification.Name("navigateToTimeline")
    static let navigateToFavorites = Notification.Name("navigateToFavorites")
    static let navigateToMemories = Notification.Name("navigateToMemories")
    static let navigateToInsights = Notification.Name("navigateToInsights")
    static let generateWritingPrompt = Notification.Name("generateWritingPrompt")
    static let showExport = Notification.Name("showExport")
    static let showImport = Notification.Name("showImport")
    static let clearMemories = Notification.Name("clearMemories")
    static let createBackup = Notification.Name("createBackup")
    static let lockGemi = Notification.Name("lockGemi")
}