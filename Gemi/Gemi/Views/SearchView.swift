import SwiftUI
import Combine

struct SearchView: View {
    @ObservedObject var journalStore: JournalStore
    @State private var searchQuery = ""
    @State private var searchResults: [JournalEntry] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    
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
                    EntryCard(
                        entry: entry,
                        isSelected: false,
                        onTap: {}
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
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
}