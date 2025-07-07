import SwiftUI

/// Production-level reading view for journal entries
struct EntryReadingView: View {
    let entry: JournalEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onChat: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeleteAlert = false
    @State private var contentScale: CGFloat = 1.0
    @State private var showingShareMenu = false
    
    // Reading preferences
    @AppStorage("readingFontSize") private var fontSize: Double = 17
    @AppStorage("readingLineSpacing") private var lineSpacing: Double = 1.5
    @State private var theme: ReadingTheme = .light
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Article-style header
                    articleHeader
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    
                    // Metadata bar
                    metadataBar
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.horizontal, 40)
                    
                    // Main content
                    contentSection
                        .padding(.horizontal, 40)
                        .padding(.vertical, 32)
                    
                    // Tags section
                    if !entry.tags.isEmpty {
                        tagsSection
                            .padding(.horizontal, 40)
                            .padding(.bottom, 32)
                    }
                    
                    // Related actions
                    relatedActionsSection
                        .padding(.horizontal, 40)
                        .padding(.bottom, 32)
                }
            }
            .background(theme.backgroundColor)
            .toolbar {
                toolbarContent
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
    }
    
    // MARK: - Article Header
    
    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date
            Text(entry.createdAt.formatted(date: .complete, time: .omitted))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            // Title
            Text(entry.displayTitle)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
            
            // Mood indicator
            if let mood = entry.mood {
                HStack(spacing: 8) {
                    Text(mood.emoji)
                        .font(.system(size: 20))
                    Text("Feeling \(mood.rawValue)")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Metadata Bar
    
    private var metadataBar: some View {
        HStack(spacing: 20) {
            // Reading time
            Label("\(entry.readingTime) min read", systemImage: "clock")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            // Word count
            Label("\(entry.wordCount) words", systemImage: "text.alignleft")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            // Last modified
            if entry.modifiedAt > entry.createdAt {
                Label("Edited \(entry.modifiedAt.formatted(.relative(presentation: .named)))", 
                      systemImage: "pencil")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Main content with custom typography
            Text(entry.content)
                .font(.system(size: fontSize, weight: .regular, design: .serif))
                .lineSpacing(fontSize * (lineSpacing - 1))
                .foregroundColor(theme.textColor)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            
        }
    }
    
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(entry.tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 11))
                        Text(tag)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Theme.Colors.primaryAccent.opacity(0.1))
                    )
                    .foregroundColor(Theme.Colors.primaryAccent)
                }
            }
        }
    }
    
    // MARK: - Related Actions
    
    private var relatedActionsSection: some View {
        VStack(spacing: 16) {
            Divider()
            
            HStack(spacing: 16) {
                // Chat about this entry
                Button(action: onChat) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("Discuss with Gemi")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.Colors.primaryAccent)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                // Edit entry
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button("Done") {
                dismiss()
            }
        }
        
        ToolbarItemGroup(placement: .primaryAction) {
            // Text size controls
            Menu {
                Button {
                    fontSize = max(14, fontSize - 1)
                } label: {
                    Label("Decrease", systemImage: "textformat.size.smaller")
                }
                
                Button {
                    fontSize = 17
                } label: {
                    Label("Reset", systemImage: "textformat.size")
                }
                
                Button {
                    fontSize = min(24, fontSize + 1)
                } label: {
                    Label("Increase", systemImage: "textformat.size.larger")
                }
            } label: {
                Image(systemName: "textformat.size")
            }
            
            // Theme toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    theme = theme == .light ? .dark : .light
                }
            } label: {
                Image(systemName: theme == .light ? "moon" : "sun.max")
            }
            
            // More actions
            Menu {
                Button {
                    // Copy to clipboard
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.content, forType: .string)
                } label: {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
                
                Button {
                    showingShareMenu = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Divider()
                
                Button {
                    entry.isFavorite.toggle()
                } label: {
                    Label(
                        entry.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: entry.isFavorite ? "star.fill" : "star"
                    )
                }
                
                Divider()
                
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete Entry", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Reading Theme

enum ReadingTheme {
    case light
    case dark
    
    var backgroundColor: Color {
        switch self {
        case .light:
            return Color(nsColor: .textBackgroundColor)
        case .dark:
            return Color(nsColor: .windowBackgroundColor)
        }
    }
    
    var textColor: Color {
        switch self {
        case .light:
            return .primary
        case .dark:
            return .primary
        }
    }
}

// MARK: - Preview

struct EntryReadingView_Previews: PreviewProvider {
    static var previews: some View {
        EntryReadingView(
            entry: JournalEntry(
                title: "A Beautiful Day",
                content: "Today was absolutely wonderful. The sun was shining, birds were singing, and I felt a deep sense of gratitude for everything in my life.",
                tags: ["gratitude", "nature", "reflection"],
                mood: .happy
            ),
            onEdit: {},
            onDelete: {},
            onChat: {}
        )
    }
}