import SwiftUI

struct FavoritesView: View {
    @ObservedObject var journalStore: JournalStore
    @State private var selectedEntry: JournalEntry?
    @State private var showingChat = false
    @State private var chatEntry: JournalEntry?
    @State private var showingComposeView = false
    @State private var editingEntry: JournalEntry?
    @State private var readingEntry: JournalEntry?
    
    private var favoriteEntries: [JournalEntry] {
        journalStore.entries.filter { $0.isFavorite }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing) {
                // Enhanced Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.yellow)
                                .symbolRenderingMode(.multicolor)
                            
                            Text("Favorites")
                                .font(Theme.Typography.sectionHeader)
                        }
                        
                        Text("\(favoriteEntries.count) starred \(favoriteEntries.count == 1 ? "entry" : "entries")")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                if favoriteEntries.isEmpty {
                    // Enhanced empty state
                    VStack(spacing: Theme.largeSpacing) {
                        ZStack {
                            // Animated gradient background
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Theme.Colors.primaryAccent.opacity(0.2),
                                            Theme.Colors.primaryAccent.opacity(0.05)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .shadow(color: Theme.Colors.primaryAccent.opacity(0.2), radius: 20, x: 0, y: 10)
                            
                            Image(systemName: "star.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.yellow)
                                .symbolRenderingMode(.multicolor)
                                .shadow(color: .yellow.opacity(0.3), radius: 10)
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
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: Theme.spacing) {
                        ForEach(favoriteEntries) { entry in
                            PremiumEntryCard(
                                entry: entry,
                                isSelected: selectedEntry?.id == entry.id,
                                onSelect: {
                                    selectedEntry = entry
                                    readingEntry = entry
                                },
                                onEdit: {
                                    editingEntry = entry
                                    showingComposeView = true
                                },
                                onDelete: {
                                    Task {
                                        await journalStore.deleteEntry(entry)
                                    }
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
                    .padding(.horizontal, 24)
                    .padding(.bottom)
                }
            }
        }
        .background(Theme.Colors.windowBackground)
        .sheet(isPresented: $showingComposeView) {
            if let entry = editingEntry {
                ProductionComposeView(
                    entry: entry,
                    onSave: { updatedEntry in
                        try await journalStore.updateEntryWithError(updatedEntry)
                        showingComposeView = false
                        editingEntry = nil
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
        .sheet(item: $readingEntry) { entry in
            EnhancedEntryReadingView(
                entry: entry,
                onEdit: {
                    readingEntry = nil
                    editingEntry = entry
                    showingComposeView = true
                },
                onDelete: {
                    readingEntry = nil
                    Task {
                        await journalStore.deleteEntry(entry)
                    }
                },
                onChat: {
                    readingEntry = nil
                    chatEntry = entry
                    showingChat = true
                }
            )
            .frame(minWidth: 700, minHeight: 600)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: favoriteEntries.count)
    }
    
    private func toggleFavorite(for entry: JournalEntry) async {
        let updatedEntry = entry
        updatedEntry.isFavorite.toggle()
        await journalStore.updateEntry(updatedEntry)
    }
}