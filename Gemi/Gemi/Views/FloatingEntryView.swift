//
//  FloatingEntryView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/3/25.
//

import SwiftUI

/// A beautiful floating window for viewing journal entries in read-only mode
struct FloatingEntryView: View {
    
    // MARK: - Dependencies
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    let entry: JournalEntry
    @State private var showingExportMenu = false
    @State private var copyConfirmation = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Floating header
            floatingHeader
            
            // Content viewer
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    // Entry metadata
                    entryMetadata
                    
                    // Entry content
                    Text(entry.content)
                        .font(ModernDesignSystem.Typography.journal)
                        .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextPrimary)
                        .textSelection(.enabled)
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(DesignSystem.Spacing.extraLarge)
            }
            
            // Bottom toolbar
            bottomToolbar
        }
        .frame(width: 700, height: 600)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusLarge)
                .fill(DesignSystem.Colors.backgroundPrimary)
                .shadow(
                    color: DesignSystem.Colors.shadowMedium,
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusLarge)
                .stroke(
                    DesignSystem.Colors.primary.opacity(0.1),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Floating Header
    
    @ViewBuilder
    private var floatingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                Text(entry.title.isEmpty ? "Journal Entry" : entry.title)
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextPrimary)
                
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextSecondary)
            }
            
            Spacer()
            
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.hover.opacity(0.5))
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape)
            .help("Close viewer (Esc)")
        }
        .padding(DesignSystem.Spacing.large)
        .background(
            Rectangle()
                .fill(DesignSystem.Colors.backgroundSecondary.opacity(0.5))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignSystem.Colors.divider.opacity(0.3))
                        .frame(height: 1)
                }
        )
    }
    
    // MARK: - Entry Metadata
    
    @ViewBuilder
    private var entryMetadata: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            if let mood = entry.mood {
                HStack(spacing: DesignSystem.Spacing.tiny) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 14))
                    Text(mood)
                        .font(ModernDesignSystem.Typography.caption)
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.small)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.primary.opacity(0.1))
                )
            }
            
            HStack(spacing: DesignSystem.Spacing.tiny) {
                Image(systemName: "character.cursor.ibeam")
                    .font(.system(size: 14))
                Text("\(entry.content.split(separator: " ").count) words")
                    .font(ModernDesignSystem.Typography.caption)
            }
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            
        }
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbar: some View {
        HStack {
            // Copy confirmation
            if copyConfirmation {
                Text("Copied to clipboard!")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.success)
                    .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: DesignSystem.Spacing.base) {
                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .gemiSecondaryButton()
                
                Menu {
                    Button("Export as Markdown...") {
                    exportAsMarkdown()
                }
                Button("Export as PDF...") {
                    exportAsPDF()
                }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .gemiSecondaryButton()
            }
        }
        .padding(DesignSystem.Spacing.large)
        .background(
            Rectangle()
                .fill(DesignSystem.Colors.backgroundSecondary.opacity(0.5))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(DesignSystem.Colors.divider.opacity(0.3))
                        .frame(height: 1)
                }
        )
    }
    
    // MARK: - Actions
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        let fullText = """
        \(entry.title.isEmpty ? "Journal Entry" : entry.title)
        \(entry.date.formatted(date: .complete, time: .shortened))
        
        \(entry.content)
        """
        
        pasteboard.setString(fullText, forType: .string)
        
        withAnimation(.spring(response: 0.3)) {
            copyConfirmation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) {
                copyConfirmation = false
            }
        }
        
        NSSound.beep()
    }
    
    private func exportAsMarkdown() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text]
        savePanel.nameFieldStringValue = "\(entry.title.isEmpty ? "Journal Entry" : entry.title).md"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            let markdown = """
            # \(entry.title.isEmpty ? "Journal Entry" : entry.title)
            
            **Date:** \(entry.date.formatted(date: .complete, time: .shortened))
            **Mood:** \(entry.mood ?? "No mood")
            
            ---
            
            \(entry.content)
            """
            
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
                NSSound.beep()
            } catch {
                print("Failed to export markdown: \(error)")
            }
        }
    }
    
    private func exportAsPDF() {
        // Use the system print panel which includes PDF export
        let printInfo = NSPrintInfo()
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72
        
        // Create a simple text view with the content
        let textView = NSTextView()
        textView.string = """
        \(entry.title.isEmpty ? "Journal Entry" : entry.title)
        
        Date: \(entry.date.formatted(date: .complete, time: .shortened))
        Mood: \(entry.mood ?? "No mood")
        
        ---
        
        \(entry.content)
        """
        textView.isEditable = false
        textView.isSelectable = false
        
        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }
}

// MARK: - Preview

#Preview("Floating Entry Viewer") {
    FloatingEntryView(
        entry: JournalEntry(
            title: "A Beautiful Day",
            content: """
            Today was absolutely wonderful. The morning started with a gentle rain that cleared up by noon, \
            leaving behind that fresh, earthy smell I love so much.
            
            I spent the afternoon at the local coffee shop, working on my novel. There's something magical \
            about the ambiance there - the soft jazz music, the aroma of freshly ground coffee beans, and \
            the gentle murmur of conversations.
            
            Later, I took a long walk through the park. The autumn leaves were at their peak, painting the \
            landscape in brilliant shades of gold, orange, and red. I collected a few particularly beautiful \
            leaves to press in my journal.
            
            As the day wound down, I felt deeply grateful for these simple pleasures. Sometimes the most \
            ordinary days turn out to be the most extraordinary ones.
            """,
            mood: "Grateful"
        )
    )
    .frame(width: 800, height: 700)
}