import SwiftUI
import Combine

struct SearchView: View {
    @ObservedObject var journalStore: JournalStore
    @State private var searchQuery = ""
    @State private var searchResults: [JournalEntry] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedEntry: JournalEntry?
    @State private var showingReadingView = false
    @State private var readingEntry: JournalEntry?
    @State private var showingComposeView = false
    @State private var editingEntry: JournalEntry?
    @State private var showingChat = false
    @State private var chatEntry: JournalEntry?
    
    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            
            Divider()
            
            if searchQuery.isEmpty {
                emptySearchState
            } else if isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                noResultsState
            } else {
                searchResultsList
            }
        }
        .background(Theme.Colors.windowBackground)
    }
    
    private var searchHeader: some View {
        VStack(spacing: Theme.spacing) {
            Text("Search Journal")
                .font(Theme.Typography.largeTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.Colors.secondaryText)
                
                TextField("Search entries, tags, moods...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .onChange(of: searchQuery) { _, newValue in
                        performRealtimeSearch(newValue)
                    }
                
                if !searchQuery.isEmpty {
                    Button(action: { 
                        searchQuery = ""
                        searchResults = []
                        searchTask?.cancel()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.smallCornerRadius)
        }
        .padding()
    }
    
    private var emptySearchState: some View {
        VStack(spacing: Theme.spacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.tertiaryText)
            
            Text("Search your journal")
                .font(Theme.Typography.title)
            
            Text("Find entries by keywords, tags, or moods")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsState: some View {
        VStack(spacing: Theme.spacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.tertiaryText)
            
            Text("No results found")
                .font(Theme.Typography.title)
            
            Text("Try searching with different keywords")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.spacing) {
                Text("\(searchResults.count) results for \"\(searchQuery)\"")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal)
                
                ForEach(searchResults) { entry in
                    EnhancedEntryCard(
                        entry: entry,
                        isSelected: selectedEntry?.id == entry.id,
                        onTap: {
                            selectedEntry = entry
                        },
                        onChat: {
                            chatEntry = entry
                            showingChat = true
                        },
                        onToggleFavorite: {
                            Task {
                                await toggleFavorite(for: entry)
                            }
                        },
                        onEdit: {
                            editingEntry = entry
                            showingComposeView = true
                        },
                        onDelete: {
                            Task {
                                await journalStore.deleteEntry(entry)
                                // Re-run search after deletion
                                performRealtimeSearch(searchQuery)
                            }
                        },
                        onRead: {
                            readingEntry = entry
                            showingReadingView = true
                        }
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingReadingView) {
            if let entry = readingEntry {
                EnhancedEntryReadingView(
                    entry: entry,
                    onEdit: {
                        showingReadingView = false
                        editingEntry = entry
                        showingComposeView = true
                    },
                    onDelete: {
                        showingReadingView = false
                        Task {
                            await journalStore.deleteEntry(entry)
                            // Re-run search after deletion
                            performRealtimeSearch(searchQuery)
                        }
                    },
                    onChat: {
                        showingReadingView = false
                        chatEntry = entry
                        showingChat = true
                    }
                )
                .frame(minWidth: 700, minHeight: 600)
            }
        }
        .sheet(isPresented: $showingComposeView) {
            if let entry = editingEntry {
                ProductionComposeView(
                    entry: entry,
                    onSave: { updatedEntry in
                        Task {
                            await journalStore.updateEntry(updatedEntry)
                            showingComposeView = false
                            editingEntry = nil
                            // Re-run search to update results
                            performRealtimeSearch(searchQuery)
                        }
                    },
                    onCancel: {
                        showingComposeView = false
                        editingEntry = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingChat) {
            if let entry = chatEntry {
                GemiChatView(contextEntry: entry)
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
    }
    
    private func performRealtimeSearch(_ query: String) {
        // Cancel any existing search task
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        // Create a new search task with debouncing
        searchTask = Task {
            // Debounce: wait 300ms before searching
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms
            } catch {
                return // Task was cancelled
            }
            
            // Check if task is still valid (not cancelled)
            guard !Task.isCancelled else { return }
            
            // Perform the search
            let results = await journalStore.searchEntries(query: query)
            
            // Update results on main thread if task hasn't been cancelled
            if !Task.isCancelled {
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            }
        }
    }
    
    private func toggleFavorite(for entry: JournalEntry) async {
        let updatedEntry = entry
        updatedEntry.isFavorite.toggle()
        await journalStore.updateEntry(updatedEntry)
        // Update search results to reflect the change
        if let index = searchResults.firstIndex(where: { $0.id == entry.id }) {
            searchResults[index] = updatedEntry
        }
    }
}