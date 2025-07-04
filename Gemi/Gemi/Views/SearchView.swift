import SwiftUI

/// SearchView provides a dedicated full-screen search interface for journal entries
struct SearchView: View {
    // MARK: - Dependencies
    
    @Environment(JournalStore.self) private var journalStore
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(PerformanceOptimizer.self) private var performanceOptimizer
    @Environment(AccessibilityManager.self) private var accessibilityManager
    
    // MARK: - State
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectedEntry: JournalEntry?
    @State private var viewingEntry: JournalEntry?
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: JournalEntry?
    
    // MARK: - Computed Properties
    
    private var searchResults: [JournalEntry] {
        if searchText.isEmpty {
            return []
        }
        return journalStore.searchEntries(searchText)
    }
    
    private var groupedResults: [Date: [JournalEntry]] {
        Dictionary(grouping: searchResults) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            searchHeader
            
            // Content
            if searchText.isEmpty {
                emptySearchState
            } else if searchResults.isEmpty {
                noResultsState
            } else {
                searchResultsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.backgroundPrimary)
        .onAppear {
            // Auto-focus search field when view appears
            isSearchFocused = true
        }
        .sheet(item: $viewingEntry) { entry in
            FloatingEntryView(entry: entry)
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
    
    // MARK: - Search Header
    
    @ViewBuilder
    private var searchHeader: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Large search bar
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                TextField("Search your journal...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                
                if !searchText.isEmpty {
                    Button {
                        withAnimation(DesignSystem.Animation.standard) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSearchFocused ? DesignSystem.Colors.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .animation(DesignSystem.Animation.standard, value: isSearchFocused)
            
            // Results count
            if !searchText.isEmpty {
                HStack {
                    Text("\(searchResults.count) results")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(DesignSystem.Spacing.contentPadding)
        .background(
            Rectangle()
                .fill(.regularMaterial.opacity(0.8))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignSystem.Colors.divider.opacity(0.3))
                        .frame(height: 1)
                }
        )
    }
    
    // MARK: - Empty Search State
    
    @ViewBuilder
    private var emptySearchState: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                Spacer(minLength: DesignSystem.Spacing.huge)
                
                // Illustration
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 80))
                    .foregroundStyle(DesignSystem.Colors.primary.opacity(0.3))
                
                // Content
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Text("Search Everything")
                        .font(DesignSystem.Typography.title1)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Text("Find any entry by searching for words in the title or content")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                
                // Search tips
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    Text("Search Tips")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    SearchTipRow(icon: "lightbulb", text: "Search is case-insensitive")
                    SearchTipRow(icon: "clock", text: "Results are sorted by date")
                    SearchTipRow(icon: "sparkles", text: "Search includes both titles and content")
                }
                .padding(DesignSystem.Spacing.large)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DesignSystem.Colors.backgroundSecondary.opacity(0.5))
                )
                .frame(maxWidth: 400)
                
                Spacer(minLength: DesignSystem.Spacing.huge)
            }
            .padding(.horizontal, DesignSystem.Spacing.panelPadding)
        }
    }
    
    // MARK: - No Results State
    
    @ViewBuilder
    private var noResultsState: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.large) {
                Spacer(minLength: DesignSystem.Spacing.huge)
                
                // Illustration
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                
                // Message
                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("No results for \"\(searchText)\"")
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Text("Try searching with different keywords")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                
                // Clear search button
                Button {
                    withAnimation(DesignSystem.Animation.standard) {
                        searchText = ""
                    }
                } label: {
                    Text("Clear Search")
                        .font(DesignSystem.Typography.callout)
                }
                .gemiSecondaryButton()
                
                Spacer(minLength: DesignSystem.Spacing.huge)
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
        }
    }
    
    // MARK: - Search Results List
    
    @ViewBuilder
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedResults.keys.sorted(by: >), id: \.self) { date in
                    Section {
                        resultsSection(for: date)
                    } header: {
                        resultsSectionHeader(for: date)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder
    private func resultsSection(for date: Date) -> some View {
        VStack(spacing: 24) {
            ForEach(groupedResults[date]!, id: \.id) { entry in
                SearchResultCard(
                    entry: entry,
                    searchText: searchText,
                    isSelected: selectedEntry?.id == entry.id,
                    action: {
                        withAnimation(DesignSystem.Animation.encouragingSpring) {
                            selectedEntry = entry
                            viewingEntry = entry
                        }
                    },
                    onEdit: {
                        navigationModel.openEntry(entry)
                    },
                    onDelete: {
                        entryToDelete = entry
                        showingDeleteAlert = true
                    }
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, DesignSystem.Spacing.medium)
        .padding(.bottom, 32)
    }
    
    @ViewBuilder
    private func resultsSectionHeader(for date: Date) -> some View {
        HStack {
            Text(formatDateHeader(date))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
            
            Spacer()
            
            Text("\(groupedResults[date]!.count) results")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .horizontal)
        )
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
    }
}

// MARK: - Supporting Views

struct SearchTipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(DesignSystem.Colors.primary)
                .frame(width: 24)
            
            Text(text)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            Spacer()
        }
    }
}

struct SearchResultCard: View {
    let entry: JournalEntry
    let searchText: String
    let isSelected: Bool
    let action: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Date and time
                Text(entry.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                
                // Title with highlighting
                if !entry.title.isEmpty {
                    Text(entry.title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                }
                
                // Content preview with highlighting
                Text(getHighlightedPreview(for: entry))
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? DesignSystem.Colors.selection : DesignSystem.Colors.backgroundPrimary)
                    .shadow(
                        color: DesignSystem.Colors.shadowLight,
                        radius: isSelected ? 12 : 8,
                        y: isSelected ? 6 : 4
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func getHighlightedPreview(for entry: JournalEntry) -> String {
        // For now, return a simple preview. In a production app, you'd highlight the search terms
        let previewLength = 150
        if entry.content.count > previewLength {
            return String(entry.content.prefix(previewLength)) + "..."
        }
        return entry.content
    }
}

// MARK: - Preview

#Preview {
    let store = (try? JournalStore()) ?? JournalStore.preview
    
    return SearchView()
        .environment(store)
        .environment(NavigationModel())
        .frame(width: 800, height: 600)
}