//
//  ContextMenus.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

// MARK: - Journal Entry Context Menu

struct JournalEntryContextMenu: View {
    let entry: JournalEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onExport: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        Group {
            Button(action: onEdit) {
                Label("Edit Entry", systemImage: "pencil")
            }
            .keyboardShortcut("e", modifiers: [])
            
            Button(action: onDuplicate) {
                Label("Duplicate Entry", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("d", modifiers: [])
            
            Divider()
            
            Menu("Export As...") {
                Button("Markdown") {
                    exportAsMarkdown()
                }
                
                Button("Plain Text") {
                    exportAsPlainText()
                }
                
                Button("PDF") {
                    exportAsPDF()
                }
            }
            
            Button(action: onShare) {
                Label("Share...", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Entry", systemImage: "trash")
            }
            .keyboardShortcut(.delete, modifiers: [])
        }
    }
    
    private func exportAsMarkdown() {
        // Implementation for markdown export
        onExport()
    }
    
    private func exportAsPlainText() {
        // Implementation for plain text export
        onExport()
    }
    
    private func exportAsPDF() {
        // Implementation for PDF export
        onExport()
    }
}

// MARK: - Editor Context Menu

struct EditorContextMenu: View {
    @Binding var selectedText: String
    let onCut: () -> Void
    let onCopy: () -> Void
    let onPaste: () -> Void
    
    var body: some View {
        Group {
            Button(action: onCut) {
                Label("Cut", systemImage: "scissors")
            }
            .keyboardShortcut("x", modifiers: .command)
            .disabled(selectedText.isEmpty)
            
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(selectedText.isEmpty)
            
            Button(action: onPaste) {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .keyboardShortcut("v", modifiers: .command)
            
            Divider()
            
            Menu("Format") {
                Button(action: { applyFormat(.bold) }) {
                    Label("Bold", systemImage: "bold")
                }
                .keyboardShortcut("b", modifiers: .command)
                
                Button(action: { applyFormat(.italic) }) {
                    Label("Italic", systemImage: "italic")
                }
                .keyboardShortcut("i", modifiers: .command)
                
                Button(action: { applyFormat(.underline) }) {
                    Label("Underline", systemImage: "underline")
                }
                .keyboardShortcut("u", modifiers: .command)
            }
            
            Divider()
            
            Button(action: lookUpDefinition) {
                Label("Look Up", systemImage: "book")
            }
            .disabled(selectedText.isEmpty)
            
            Button(action: searchWeb) {
                Label("Search Web", systemImage: "globe")
            }
            .disabled(selectedText.isEmpty)
        }
    }
    
    private func applyFormat(_ format: TextFormat) {
        // Implementation for text formatting
    }
    
    private func lookUpDefinition() {
        // Implementation for dictionary lookup
        NSWorkspace.shared.open(URL(string: "dict://\(selectedText)")!)
    }
    
    private func searchWeb() {
        // Implementation for web search
        if let encoded = selectedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            NSWorkspace.shared.open(URL(string: "https://www.google.com/search?q=\(encoded)")!)
        }
    }
}


// MARK: - Timeline Context Menu

struct TimelineContextMenu: View {
    let onNewEntry: () -> Void
    let onRefresh: () -> Void
    let onSort: (SortOption) -> Void
    
    var body: some View {
        Group {
            Button(action: onNewEntry) {
                Label("New Entry", systemImage: "plus.circle")
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Divider()
            
            Menu("Sort By") {
                Button(action: { onSort(.dateNewest) }) {
                    Label("Date (Newest First)", systemImage: "arrow.down")
                }
                
                Button(action: { onSort(.dateOldest) }) {
                    Label("Date (Oldest First)", systemImage: "arrow.up")
                }
                
                Button(action: { onSort(.modified) }) {
                    Label("Recently Modified", systemImage: "clock")
                }
            }
            
            Button(action: onRefresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}

enum SortOption {
    case dateNewest, dateOldest, modified
}

// MARK: - AI Chat Context Menu

struct AIChatContextMenu: View {
    let message: String
    let onCopy: () -> Void
    let onRegenerate: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        Group {
            Button(action: onCopy) {
                Label("Copy Message", systemImage: "doc.on.doc")
            }
            
            Button(action: onEdit) {
                Label("Edit Message", systemImage: "pencil")
            }
            
            Divider()
            
            Button(action: onRegenerate) {
                Label("Regenerate Response", systemImage: "arrow.clockwise")
            }
        }
    }
}

// MARK: - Memory Item Context Menu

struct MemoryItemContextMenu: View {
    let memory: MemoryItem
    let onViewSource: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Group {
            Button(action: onViewSource) {
                Label("View Source Entry", systemImage: "doc.text")
            }
            
            Button(action: onEdit) {
                Label("Edit Memory", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Memory", systemImage: "trash")
            }
        }
    }
}

// MARK: - Generic Context Menu Modifier

struct NativeContextMenu<MenuContent: View>: ViewModifier {
    @ViewBuilder let menuContent: () -> MenuContent
    
    func body(content: Content) -> some View {
        content
            .contextMenu(menuItems: menuContent)
    }
}

extension View {
    func nativeContextMenu<MenuContent: View>(
        @ViewBuilder menuItems: @escaping () -> MenuContent
    ) -> some View {
        self.modifier(NativeContextMenu(menuContent: menuItems))
    }
}

// MARK: - Context Menu Styles

struct ContextMenuLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            configuration.title
                .font(.system(size: 13))
        }
    }
}

