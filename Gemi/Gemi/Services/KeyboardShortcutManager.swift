//
//  KeyboardShortcutManager.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

/// Defines all keyboard shortcuts for Gemi
struct KeyboardShortcuts {
    
    // MARK: - Journal Actions
    
    static let newEntry = KeyboardShortcut("N", modifiers: .command)
    static let saveEntry = KeyboardShortcut("S", modifiers: .command)
    static let deleteEntry = KeyboardShortcut(.delete, modifiers: .command)
    static let duplicateEntry = KeyboardShortcut("D", modifiers: .command)
    
    // MARK: - Navigation
    
    static let previousEntry = KeyboardShortcut(.upArrow, modifiers: .command)
    static let nextEntry = KeyboardShortcut(.downArrow, modifiers: .command)
    static let goToToday = KeyboardShortcut("T", modifiers: [.command, .shift])
    static let search = KeyboardShortcut("F", modifiers: .command)
    
    // MARK: - AI Features
    
    static let talkToGemi = KeyboardShortcut("T", modifiers: .command)
    static let showMemories = KeyboardShortcut("M", modifiers: [.command, .shift])
    static let clearChat = KeyboardShortcut("K", modifiers: .command)
    
    // MARK: - View Controls
    
    static let toggleSidebar = KeyboardShortcut("S", modifiers: [.command, .option])
    static let toggleFullScreen = KeyboardShortcut(.return, modifiers: [.command, .control])
    static let showSettings = KeyboardShortcut(",", modifiers: .command)
    static let closeWindow = KeyboardShortcut("W", modifiers: .command)
    
    // MARK: - Text Editing
    
    static let bold = KeyboardShortcut("B", modifiers: .command)
    static let italic = KeyboardShortcut("I", modifiers: .command)
    static let underline = KeyboardShortcut("U", modifiers: .command)
    static let increaseTextSize = KeyboardShortcut("+", modifiers: .command)
    static let decreaseTextSize = KeyboardShortcut("-", modifiers: .command)
    
    // MARK: - Special Features
    
    static let voiceInput = KeyboardShortcut(.space, modifiers: [.command, .shift])
    static let attachImage = KeyboardShortcut("I", modifiers: [.command, .shift])
    static let exportEntry = KeyboardShortcut("E", modifiers: [.command, .shift])
}

// MARK: - Keyboard Shortcut View Modifier

struct KeyboardShortcutHandler: ViewModifier {
    let shortcut: KeyboardShortcut
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
    }
}

// MARK: - Focus Management

enum FocusableField: Hashable {
    case search
    case editor
    case chatInput
    case settings
}

// MARK: - Keyboard Navigation State

@Observable
final class KeyboardNavigationState {
    var focusedField: FocusableField?
    var selectedEntryIndex: Int = 0
    var isNavigatingWithKeyboard = false
    
    func selectPreviousEntry(totalEntries: Int) {
        guard totalEntries > 0 else { return }
        selectedEntryIndex = max(0, selectedEntryIndex - 1)
        isNavigatingWithKeyboard = true
    }
    
    func selectNextEntry(totalEntries: Int) {
        guard totalEntries > 0 else { return }
        selectedEntryIndex = min(totalEntries - 1, selectedEntryIndex + 1)
        isNavigatingWithKeyboard = true
    }
    
    func resetKeyboardNavigation() {
        isNavigatingWithKeyboard = false
    }
}

// MARK: - Keyboard Commands

struct GemiKeyboardCommands: Commands {
    @FocusedBinding(\.journalStore) var journalStore: JournalStore?
    @FocusedValue(\.selectedEntry) var selectedEntry: JournalEntry?
    @FocusedBinding(\.showSettings) var showSettings: Bool?
    @FocusedBinding(\.showChat) var showChat: Bool?
    
    var body: some Commands {
        // File Menu
        CommandGroup(after: .newItem) {
            Button("New Entry") {
                // Handle new entry
            }
            .keyboardShortcut("N", modifiers: .command)
            
            Divider()
            
            Button("Export Entry...") {
                // Handle export
            }
            .keyboardShortcut("E", modifiers: [.command, .shift])
            .disabled(selectedEntry == nil)
        }
        
        // Edit Menu
        CommandGroup(after: .pasteboard) {
            Divider()
            
            Button("Bold") {
                // Handle bold
            }
            .keyboardShortcut("B", modifiers: .command)
            
            Button("Italic") {
                // Handle italic
            }
            .keyboardShortcut("I", modifiers: .command)
            
            Button("Underline") {
                // Handle underline
            }
            .keyboardShortcut("U", modifiers: .command)
        }
        
        // Gemi Menu
        CommandMenu("Gemi") {
            Button("Chat with Gemma 3n") {
                showChat? = true
            }
            .keyboardShortcut("T", modifiers: .command)
            
            Divider()
            
            Button("Show Memories") {
                // Handle show memories
            }
            .keyboardShortcut("M", modifiers: [.command, .shift])
            
            Button("View Insights") {
                // Handle insights view
            }
            .keyboardShortcut("I", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Voice Input") {
                // Handle voice input
            }
            .keyboardShortcut(.space, modifiers: [.command, .shift])
        }
        
        // View Menu - Add to system View menu instead of creating new one
        CommandGroup(after: .sidebar) {
            Divider()
            
            Button("Toggle Sidebar") {
                // Handle sidebar toggle
            }
            .keyboardShortcut("S", modifiers: [.command, .option])
            
            Button("Go to Today") {
                // Handle go to today
            }
            .keyboardShortcut("T", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Increase Text Size") {
                // Handle text size
            }
            .keyboardShortcut("+", modifiers: .command)
            
            Button("Decrease Text Size") {
                // Handle text size
            }
            .keyboardShortcut("-", modifiers: .command)
        }
    }
}

// MARK: - Focused Values

private struct JournalStoreFocusedKey: FocusedValueKey {
    typealias Value = Binding<JournalStore>
}

private struct SelectedEntryFocusedKey: FocusedValueKey {
    typealias Value = JournalEntry?
}

private struct ShowSettingsFocusedKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

private struct ShowChatFocusedKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var journalStore: Binding<JournalStore>? {
        get { self[JournalStoreFocusedKey.self] }
        set { self[JournalStoreFocusedKey.self] = newValue }
    }
    
    var selectedEntry: JournalEntry? {
        get { self[SelectedEntryFocusedKey.self] ?? nil }
        set { self[SelectedEntryFocusedKey.self] = newValue }
    }
    
    var showSettings: Binding<Bool>? {
        get { self[ShowSettingsFocusedKey.self] }
        set { self[ShowSettingsFocusedKey.self] = newValue }
    }
    
    var showChat: Binding<Bool>? {
        get { self[ShowChatFocusedKey.self] }
        set { self[ShowChatFocusedKey.self] = newValue }
    }
}