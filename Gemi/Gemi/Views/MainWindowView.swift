import SwiftUI

struct MainWindowView: View {
    @State private var selectedView: NavigationItem = .timeline
    @State private var selectedEntry: JournalEntry? = nil
    @State private var editingEntry: JournalEntry? = nil
    @State private var showingReadingView = false
    @StateObject private var journalStore = JournalStore()
    
    var body: some View {
        HSplitView {
            Sidebar(selectedView: $selectedView, journalStore: journalStore)
                .frame(minWidth: Theme.sidebarWidth, maxWidth: Theme.sidebarWidth)
            
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.Colors.windowBackground)
        .frame(minWidth: Theme.minWindowWidth, minHeight: Theme.minWindowHeight)
        .onAppear {
            Task {
                await journalStore.loadEntries()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newEntry)) { _ in
            selectedView = .compose
        }
        .onReceive(NotificationCenter.default.publisher(for: .search)) { _ in
            selectedView = .search
        }
        .onReceive(NotificationCenter.default.publisher(for: .openChat)) { _ in
            selectedView = .chat
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedView {
        case .timeline:
            EnhancedTimelineView(
                journalStore: journalStore,
                selectedEntry: $selectedEntry,
                onNewEntry: {
                    selectedView = .compose
                },
                onEditEntry: { entry in
                    editingEntry = entry
                    selectedView = .compose
                }
            )
        case .compose:
            ProductionComposeView(
                entry: editingEntry,
                onSave: { entry in
                    Task {
                        await journalStore.saveEntry(entry)
                        selectedView = .timeline
                        editingEntry = nil
                        // Find the saved entry from the refreshed entries array
                        selectedEntry = journalStore.entries.first { $0.id == entry.id }
                    }
                },
                onCancel: {
                    selectedView = .timeline
                    editingEntry = nil
                }
            )
        case .chat:
            GemiChatView()
        case .favorites:
            FavoritesView(journalStore: journalStore)
        case .search:
            SearchView(journalStore: journalStore)
        case .memories:
            MemoriesView()
        case .insights:
            InsightsView(entries: journalStore.entries)
        }
    }
}

@MainActor
final class JournalStore: ObservableObject {
    @Published var entries: [JournalEntry] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let databaseManager = DatabaseManager.shared
    
    var favoriteEntries: [JournalEntry] {
        entries.filter { $0.isFavorite }
    }
    
    func loadEntries() async {
        isLoading = true
        error = nil
        
        do {
            try await databaseManager.initialize()
            entries = try await databaseManager.loadEntries()
            
            // If no entries exist, create some sample entries for demo
            if entries.isEmpty && !UserDefaults.standard.bool(forKey: "hasCreatedSampleEntries") {
                await createSampleEntries()
                UserDefaults.standard.set(true, forKey: "hasCreatedSampleEntries")
            }
        } catch {
            self.error = error
            print("Failed to load entries: \(error)")
            
            // Use mock data if database fails
            await MainActor.run {
                self.entries = JournalEntry.mockEntries()
            }
        }
        
        isLoading = false
    }
    
    private func createSampleEntries() async {
        let sampleEntries = JournalEntry.mockEntries()
        for entry in sampleEntries {
            do {
                try await databaseManager.saveEntry(entry)
            } catch {
                print("Failed to save sample entry: \(error)")
            }
        }
        
        // Reload entries
        do {
            entries = try await databaseManager.loadEntries()
        } catch {
            print("Failed to reload entries: \(error)")
        }
    }
    
    func saveEntry(_ entry: JournalEntry) async {
        do {
            try await databaseManager.saveEntry(entry)
            await loadEntries()
        } catch {
            self.error = error
            print("Failed to save entry: \(error)")
        }
    }
    
    func deleteEntry(_ entry: JournalEntry) async {
        do {
            try await databaseManager.deleteEntry(entry.id)
            await loadEntries()
        } catch {
            self.error = error
            print("Failed to delete entry: \(error)")
        }
    }
    
    func updateEntry(_ entry: JournalEntry) async {
        do {
            // Use saveEntry for updates as well
            try await databaseManager.saveEntry(entry)
            await loadEntries()
        } catch {
            self.error = error
            print("Failed to update entry: \(error)")
        }
    }
    
    func searchEntries(query: String) async -> [JournalEntry] {
        do {
            return try await databaseManager.searchEntries(query: query)
        } catch {
            self.error = error
            print("Failed to search entries: \(error)")
            return []
        }
    }
}

struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView()
    }
}