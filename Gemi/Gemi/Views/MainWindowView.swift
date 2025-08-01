import SwiftUI

struct MainWindowView: View {
    @State private var selectedView: NavigationItem = .home
    @State private var selectedEntry: JournalEntry? = nil
    @State private var editingEntry: JournalEntry? = nil
    @State private var showingReadingView = false
    @State private var showingCommandPalette = false
    @State private var showingFocusMode = false
    @State private var focusModeEntry: JournalEntry? = nil
    @StateObject private var journalStore = JournalStore()
    
    var body: some View {
        ZStack {
            // Enhanced background with visual effects
            ZStack {
                // Base window background
                VisualEffectView.windowBackground
                    .ignoresSafeArea()
                
                // Subtle animated gradient overlay
                Theme.Gradients.timeBasedGradient()
                    .opacity(0.05)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 3), value: Date())
            }
            
            HSplitView {
                Sidebar(selectedView: $selectedView, journalStore: journalStore)
                    .frame(minWidth: Theme.sidebarWidth, maxWidth: Theme.sidebarWidth)
                
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        VisualEffectView.contentBackground
                            .opacity(0.5)
                    )
                    .ignoresSafeArea()
            }
            .frame(minWidth: Theme.minWindowWidth, minHeight: Theme.minWindowHeight)
            .ignoresSafeArea()
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
            .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
                showingCommandPalette = true
            }
            // Navigation notifications from command palette
            .onReceive(NotificationCenter.default.publisher(for: .navigateToHome)) { _ in
                selectedView = .home
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToTimeline)) { _ in
                selectedView = .timeline
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToFavorites)) { _ in
                selectedView = .favorites
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToMemories)) { _ in
                selectedView = .memories
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToInsights)) { _ in
                selectedView = .insights
            }
            
            // Command Palette Overlay
            if showingCommandPalette {
                CommandPaletteView(isShowing: $showingCommandPalette)
                    .zIndex(1000)
            }
            
            // Focus Mode Overlay
            if showingFocusMode, let focusEntry = focusModeEntry {
                FocusModeView(
                    entry: Binding(
                        get: { focusEntry },
                        set: { updatedEntry in
                            focusModeEntry = updatedEntry
                            if editingEntry != nil {
                                self.editingEntry = updatedEntry
                            }
                        }
                    ),
                    isPresented: $showingFocusMode
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.02)),
                    removal: .opacity.combined(with: .scale(scale: 0.98))
                ))
                .zIndex(2000)
            }
        }
        .unifiedWindowStyle()
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedView {
        case .home:
            TimeAwareHomeView(
                journalStore: journalStore,
                onNewEntry: {
                    selectedView = .compose
                }
            )
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
                    // Save the entry but stay in compose view
                    try await journalStore.saveEntryWithError(entry)
                    // Update the editing entry with the saved version
                    editingEntry = entry
                    // Update selected entry for sidebar highlighting
                    selectedEntry = journalStore.entries.first { $0.id == entry.id }
                },
                onCancel: {
                    selectedView = .timeline
                    editingEntry = nil
                },
                onFocusMode: { entry in
                    focusModeEntry = entry
                    withAnimation(.easeOut(duration: 0.4)) {
                        showingFocusMode = true
                    }
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
        
        do {
            // Preload encryption key to prevent repeated keychain prompts
            try await databaseManager.preloadEncryptionKey()
            
            // Save all entries using batch operation
            try await databaseManager.saveEntries(sampleEntries)
            
            // Reload entries
            entries = try await databaseManager.loadEntries()
        } catch {
            print("Failed to create sample entries: \(error)")
        }
    }
    
    func saveEntry(_ entry: JournalEntry) async {
        do {
            try await databaseManager.saveEntry(entry)
            await loadEntries()
            
            // Extract memories from the new entry using AI
            Task {
                await GemiAICoordinator.shared.processJournalEntry(entry)
            }
        } catch {
            self.error = error
            print("Failed to save entry: \(error)")
        }
    }
    
    // Throwing version for auto-save
    func saveEntryWithError(_ entry: JournalEntry) async throws {
        try await databaseManager.saveEntry(entry)
        await loadEntries()
        
        // Extract memories from the new entry using AI
        Task {
            await GemiAICoordinator.shared.processJournalEntry(entry)
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
    
    // Throwing version for auto-save
    func updateEntryWithError(_ entry: JournalEntry) async throws {
        try await databaseManager.saveEntry(entry)
        await loadEntries()
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