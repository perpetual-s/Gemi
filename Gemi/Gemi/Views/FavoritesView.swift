import SwiftUI

struct FavoritesView: View {
    @ObservedObject var journalStore: JournalStore
    @State private var selectedEntry: JournalEntry?
    @State private var showingChat = false
    @State private var chatEntry: JournalEntry?
    @State private var showingComposeView = false
    @State private var editingEntry: JournalEntry?
    
    private var favoriteEntries: [JournalEntry] {
        journalStore.entries.filter { $0.isFavorite }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.yellow)
                            .symbolRenderingMode(.multicolor)
                        
                        Text("Favorites")
                            .font(Theme.Typography.largeTitle)
                    }
                    
                    Text("\(favoriteEntries.count) starred \(favoriteEntries.count == 1 ? "entry" : "entries")")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                Spacer()
            }
            .padding()
            
            Divider()
            
            if favoriteEntries.isEmpty {
                // Enhanced empty state
                VStack(spacing: Theme.largeSpacing) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primaryAccent.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 56))
                            .foregroundColor(Theme.Colors.primaryAccent.opacity(0.3))
                            .symbolRenderingMode(.hierarchical)
                    }
                    
                    VStack(spacing: Theme.spacing) {
                        Text("No favorites yet")
                            .font(Theme.Typography.title)
                        
                        Text("Star your most meaningful entries to\nquickly access them here")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.spacing) {
                        ForEach(favoriteEntries) { entry in
                            EnhancedEntryCard(
                                entry: entry,
                                isSelected: selectedEntry?.id == entry.id,
                                onTap: {
                                    selectedEntry = entry
                                    editingEntry = entry
                                    showingComposeView = true
                                },
                                onChat: {
                                    chatEntry = entry
                                    showingChat = true
                                },
                                onToggleFavorite: {
                                    Task {
                                        await toggleFavorite(for: entry)
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .scale)
                            ))
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Theme.Colors.windowBackground)
        .sheet(isPresented: $showingComposeView) {
            if let entry = editingEntry {
                ProductionComposeView(
                    entry: entry,
                    onSave: { updatedEntry in
                        Task {
                            await journalStore.updateEntry(updatedEntry)
                            showingComposeView = false
                            editingEntry = nil
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: favoriteEntries.count)
    }
    
    private func toggleFavorite(for entry: JournalEntry) async {
        let updatedEntry = entry
        updatedEntry.isFavorite.toggle()
        await journalStore.updateEntry(updatedEntry)
    }
}