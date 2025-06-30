import SwiftUI

/// TimelineView serves as the main interface for displaying journal entries in Gemi.
/// This view provides a chronological list of all journal entries with native macOS styling
/// and navigation controls for creating new entries and accessing the AI chat feature.
///
/// Architecture:
/// - Uses @Environment to access JournalStore (Swift 6 pattern)
/// - Native macOS List component for optimal platform integration
/// - Toolbar with macOS-native button styling
/// - Privacy-focused design with local-only data display
struct TimelineView: View {
    
    // MARK: - Dependencies
    
    /// The journal store containing all entries (injected via @Environment)
    @Environment(JournalStore.self) private var journalStore
    
    // MARK: - State
    
    /// Controls the presentation of the new entry creation view
    @State private var showingNewEntry = false
    
    /// Controls the presentation of the AI chat overlay
    @State private var showingChat = false
    
    /// Selected entry for potential future detail view or actions
    @Binding var selectedEntry: JournalEntry?
    
    /// Controls the alert for entry deletion confirmation
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: JournalEntry?
    
    private var groupedEntries: [Date: [JournalEntry]] {
        Dictionary(grouping: journalStore.entries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                if journalStore.isLoading && journalStore.entries.isEmpty {
                    // Loading state for initial load
                    loadingView
                } else if journalStore.entries.isEmpty {
                    // Empty state when no entries exist
                    emptyStateView
                } else {
                    // Main timeline list
                    timelineList
                }
                
                // Error overlay
                if let errorMessage = journalStore.errorMessage {
                    errorOverlay(message: errorMessage)
                }
            }
            .navigationTitle("Gemi")
            .toolbar(content: {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Talk to Gemi button
                    Button {
                        showingChat = true
                    } label: {
                        Label("Talk to Gemi", systemImage: "message.circle")
                    }
                    .help("Start a conversation with your AI journal companion")
                    
                    // New Entry button
                    Button {
                        showingNewEntry = true
                    } label: {
                        Label("New Entry", systemImage: "square.and.pencil")
                    }
                    .help("Create a new journal entry")
                    .keyboardShortcut("n", modifiers: .command)
                }
                
                ToolbarItemGroup(placement: .secondaryAction) {
                    // Refresh button
                    Button {
                        Task {
                            await journalStore.refreshEntries()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh journal entries")
                    .disabled(journalStore.isLoading)
                }
            })
        }
        .onAppear {
            Task {
                await journalStore.refreshEntries()
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            ComposeView(entry: .constant(nil))
        }
        .sheet(isPresented: $showingChat) {
            // TODO: Replace with actual ChatOverlay when implemented
            chatPlaceholder
        }
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    Task {
                        try? await journalStore.deleteEntry(entry)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this journal entry? This action cannot be undone.")
        }
    }
    
    // MARK: - Timeline List
    
    @ViewBuilder
    private var timelineList: some View {
        List(selection: $selectedEntry) {
            ForEach(groupedEntries.keys.sorted(by: >), id: \.self) { date in
                Section {
                    ForEach(groupedEntries[date]!) { entry in
                        TimelineEntryRow(entry: entry) {
                            // Delete action
                            entryToDelete = entry
                            showingDeleteAlert = true
                        }
                        .tag(entry)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                } header: {
                    HStack {
                        Text(date, style: .date)
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.top, DesignSystem.Spacing.small)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable {
            await journalStore.refreshEntries()
        }
    }
    
    // MARK: - Loading State
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.base) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(DesignSystem.Colors.primary)
            
            Text("Loading your journal entries...")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.backgroundPrimary)
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.extraLarge) {
            // Icon
            Image(systemName: "book.pages")
                .font(.system(size: 64))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
            
            // Title and description
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("Welcome to Gemi")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Your private AI journal companion")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                Text("Start by creating your first journal entry, or chat with Gemi about your thoughts and feelings.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Action buttons
            HStack(spacing: DesignSystem.Spacing.base) {
                Button {
                    showingNewEntry = true
                } label: {
                    Label("Write First Entry", systemImage: "square.and.pencil")
                }
                .gemiPrimaryButton()
                
                Button {
                    showingChat = true
                } label: {
                    Label("Talk to Gemi", systemImage: "message.circle")
                }
                .gemiSecondaryButton()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.backgroundPrimary)
        .padding()
    }
    
    // MARK: - Error Overlay
    
    @ViewBuilder
    private func errorOverlay(message: String) -> some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                
                Text(message)
                    .font(.body)
                
                Button("Dismiss") {
                    journalStore.clearError()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 8)
            .padding()
        }
    }
    
    // MARK: - Placeholder Views (TODO: Replace with actual implementations)
    
    @ViewBuilder
    private var chatPlaceholder: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "message.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("Talk to Gemi")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("This will be replaced with the actual ChatOverlay in the next phase.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Close") {
                    showingChat = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Chat with Gemi")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showingChat = false
                    }
                }
            }
        }
    }
}

// MARK: - Timeline Entry Row

/// Modern timeline entry row with consistent sizing and elegant design
private struct TimelineEntryRow: View {
    let entry: JournalEntry
    let onDelete: () -> Void
    
    // MARK: - Constants
    
    private let contentPreviewLength = 120
    private let rowHeight: CGFloat = 72 // Fixed height for consistency
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            // Date indicator - compact and modern
            VStack(spacing: 2) {
                Text(entry.date, style: .date)
                    .font(DesignSystem.Typography.caption1)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                Text(entry.date, style: .time)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .frame(width: 60, alignment: .leading)
            
            // Main content area
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                // Title from first line
                Text(entryTitle)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                
                // Content preview
                Text(contentPreview)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Metadata row
                HStack(spacing: DesignSystem.Spacing.small) {
                    Text("\(wordCount) words")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    
                    Spacer()
                    
                    // Actions button
                    Menu {
                        Button {
                            // TODO: Add edit functionality in future phase
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .disabled(true)
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .menuStyle(.borderlessButton)
                    .help("Entry options")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: rowHeight, alignment: .top)
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                .fill(DesignSystem.Colors.backgroundSecondary.opacity(0.3))
        )
        .contentShape(Rectangle())
    }
    
    // MARK: - Computed Properties
    
    private var entryTitle: String {
        let trimmed = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "Untitled Entry"
        }
        
        // Get first line or first 40 characters for title
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? ""
        let title = String(firstLine.prefix(40))
        
        return title.isEmpty ? "Untitled Entry" : (title.count < firstLine.count ? title + "..." : title)
    }
    
    private var contentPreview: String {
        let trimmed = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "No content"
        }
        
        // Skip the first line (used as title) and get preview from remaining content
        let lines = trimmed.components(separatedBy: .newlines)
        let contentLines = lines.count > 1 ? Array(lines.dropFirst()).joined(separator: " ") : trimmed
        
        if contentLines.count <= contentPreviewLength {
            return contentLines
        }
        
        let preview = String(contentLines.prefix(contentPreviewLength))
        // Try to break at a word boundary
        if let lastSpace = preview.lastIndex(of: " ") {
            return String(preview[..<lastSpace]) + "..."
        }
        
        return preview + "..."
    }
    
    private var wordCount: Int {
        entry.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}

// MARK: - Previews

#Preview("Timeline with Entries") {
    let store: JournalStore = {
        do {
            return try JournalStore()
        } catch {
            fatalError("Failed to create JournalStore for preview")
        }
    }()
    
    return TimelineView(selectedEntry: .constant(nil))
        .environment(store)
        .frame(width: 800, height: 600)
}

#Preview("Empty Timeline") {
    let emptyStore: JournalStore = {
        do {
            return try JournalStore()
        } catch {
            fatalError("Failed to create JournalStore for preview")
        }
    }()
    
    return TimelineView(selectedEntry: .constant(nil))
        .environment(emptyStore)
        .frame(width: 800, height: 600)
} 