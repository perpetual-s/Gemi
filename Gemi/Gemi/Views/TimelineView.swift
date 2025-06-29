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
    @State private var selectedEntryId: UUID?
    
    /// Controls the alert for entry deletion confirmation
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: JournalEntry?
    
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
            .toolbar {
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
            }
        }
        .onAppear {
            Task {
                await journalStore.refreshEntries()
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            ComposeView()
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
        List(journalStore.entries, selection: $selectedEntryId) { entry in
            TimelineEntryRow(entry: entry) {
                // Delete action
                entryToDelete = entry
                showingDeleteAlert = true
            }
            .listRowSeparator(.visible)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .refreshable {
            await journalStore.refreshEntries()
        }
    }
    
    // MARK: - Loading State
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading your journal entries...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "book.pages")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            // Title and description
            VStack(spacing: 8) {
                Text("Welcome to Gemi")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Your private AI journal companion")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Start by creating your first journal entry, or chat with Gemi about your thoughts and feelings.")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button {
                    showingNewEntry = true
                } label: {
                    Label("Write First Entry", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button {
                    showingChat = true
                } label: {
                    Label("Talk to Gemi", systemImage: "message.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// Individual row component for displaying a journal entry in the timeline
private struct TimelineEntryRow: View {
    let entry: JournalEntry
    let onDelete: () -> Void
    
    // MARK: - Constants
    
    private let maxContentLines = 3
    private let contentPreviewLength = 150
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Date indicator
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, style: .date)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 80, alignment: .leading)
            
            // Content preview
            VStack(alignment: .leading, spacing: 6) {
                Text(contentPreview)
                    .font(.body)
                    .lineLimit(maxContentLines)
                    .multilineTextAlignment(.leading)
                
                // Word count indicator
                Text("\(wordCount) words")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Actions menu
            Menu {
                Button {
                    // TODO: Add edit functionality in future phase
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .disabled(true) // Disabled until edit functionality is implemented
                
                Divider()
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .help("Entry options")
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    // MARK: - Computed Properties
    
    private var contentPreview: String {
        let trimmed = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.count <= contentPreviewLength {
            return trimmed
        }
        
        let preview = String(trimmed.prefix(contentPreviewLength))
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
    
    return TimelineView()
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
    
    return TimelineView()
        .environment(emptyStore)
        .frame(width: 800, height: 600)
} 