//
//  HeaderOverflowMenu.swift
//  Gemi
//
//  Elegant overflow menu for secondary actions in the header
//

import SwiftUI

struct HeaderOverflowMenu: View {
    @Binding var showingMenu: Bool
    
    let onFocusMode: (() -> Void)?
    let onWritingPrompts: () -> Void
    let onDocumentInfo: () -> Void
    
    @State private var menuOpacity: Double = 0
    @State private var menuScale: CGFloat = 0.95
    
    var body: some View {
        Menu {
            // Focus Mode
            if let onFocusMode = onFocusMode {
                Button {
                    onFocusMode()
                } label: {
                    Label("Focus Mode", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
            
            // Writing Prompts
            Button {
                onWritingPrompts()
            } label: {
                Label("Writing Prompts", systemImage: "books.vertical")
            }
            
            Divider()
            
            // Document Info
            Button {
                onDocumentInfo()
            } label: {
                Label("Document Info", systemImage: "info.circle")
            }
            .keyboardShortcut("i", modifiers: .command)
            
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(showingMenu ? 0.08 : 0))
                )
                .scaleEffect(showingMenu ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: showingMenu)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .menuIndicator(.hidden)
        .onTapGesture {
            showingMenu.toggle()
        }
    }
}

// MARK: - Document Info Sheet

struct DocumentInfoSheet: View {
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    
    private var statistics: EntryStatistics {
        EntryStatistics(from: entry)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Document Information")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(20)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Basic Info
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: "Created", value: entry.createdAt.formatted(date: .complete, time: .shortened))
                            InfoRow(label: "Modified", value: entry.modifiedAt.formatted(date: .complete, time: .shortened))
                            InfoRow(label: "ID", value: entry.id.uuidString, monospace: true)
                        }
                    } label: {
                        Label("Metadata", systemImage: "doc.text")
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    // Statistics
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: "Words", value: "\(statistics.wordCount)")
                            InfoRow(label: "Characters", value: "\(statistics.characterCount)")
                            InfoRow(label: "Sentences", value: "\(statistics.sentenceCount)")
                            InfoRow(label: "Paragraphs", value: "\(statistics.paragraphCount)")
                            InfoRow(label: "Reading Time", value: "\(statistics.readingTime) min")
                        }
                    } label: {
                        Label("Statistics", systemImage: "chart.bar")
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    // Content Analysis
                    if statistics.mostFrequentWords.count > 0 {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Most Frequent Words")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 8) {
                                    ForEach(statistics.mostFrequentWords.prefix(5), id: \.0) { word, count in
                                        Tag(text: "\(word) (\(count))")
                                    }
                                }
                            }
                        } label: {
                            Label("Analysis", systemImage: "text.magnifyingglass")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    var monospace: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(monospace ? .system(size: 13, design: .monospaced) : .system(size: 13))
                .foregroundColor(.primary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

struct Tag: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.1))
            )
            .foregroundColor(.accentColor)
    }
}

// MARK: - Entry Statistics

struct EntryStatistics {
    let wordCount: Int
    let characterCount: Int
    let sentenceCount: Int
    let paragraphCount: Int
    let readingTime: Int
    let mostFrequentWords: [(String, Int)]
    
    init(from entry: JournalEntry) {
        let content = entry.content
        
        // Word count
        let words = content.split { $0.isWhitespace || $0.isNewline }
        self.wordCount = words.filter { !$0.isEmpty }.count
        
        // Character count
        self.characterCount = content.count
        
        // Sentence count
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.sentenceCount = sentences.count
        
        // Paragraph count
        let paragraphs = content.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.paragraphCount = paragraphs.count
        
        // Reading time (200 words per minute)
        self.readingTime = max(1, wordCount / 200)
        
        // Most frequent words
        var wordFrequency: [String: Int] = [:]
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "from", "as", "is", "was", "are", "were", "been", "be", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "can", "i", "you", "he", "she", "it", "we", "they", "my", "your", "his", "her", "its", "our", "their"])
        
        for word in words {
            let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if cleanWord.count > 3 && !stopWords.contains(cleanWord) {
                wordFrequency[cleanWord, default: 0] += 1
            }
        }
        
        self.mostFrequentWords = wordFrequency
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { ($0.key, $0.value) }
    }
}