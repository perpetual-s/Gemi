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
        VStack(spacing: Theme.largeSpacing) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.Colors.primaryAccent.opacity(0.1),
                                Theme.Colors.primaryAccent.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 56))
                    .foregroundColor(Theme.Colors.primaryAccent)
            }
            
            VStack(spacing: Theme.spacing) {
                Text("Search your journal")
                    .font(Theme.Typography.title)
                    .foregroundColor(.primary)
                
                Text("Find entries by keywords, tags, or moods.\nTry searching for specific memories or feelings.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsState: some View {
        VStack(spacing: Theme.largeSpacing) {
            // Icon with muted background
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 56))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            
            VStack(spacing: Theme.spacing) {
                Text("No results found")
                    .font(Theme.Typography.title)
                    .foregroundColor(.primary)
                
                Text("Try different keywords or check your spelling.\nYou can also search by mood or date.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
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
                    PremiumEntryCard(
                        entry: entry,
                        isSelected: selectedEntry?.id == entry.id,
                        onSelect: {
                            selectedEntry = entry
                            readingEntry = entry
                            showingReadingView = true
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
                        onChat: {
                            chatEntry = entry
                            showingChat = true
                        }
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .dismissableSheet(isPresented: $showingReadingView) {
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