import SwiftUI

struct SearchView: View {
    @ObservedObject var journalStore: JournalStore
    @State private var searchQuery = ""
    @State private var searchResults: [JournalEntry] = []
    @State private var isSearching = false
    
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
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
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
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        
        Task {
            searchResults = await journalStore.searchEntries(query: searchQuery)
            isSearching = false
        }
    }
}