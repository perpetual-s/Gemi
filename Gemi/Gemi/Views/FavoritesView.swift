import SwiftUI

struct FavoritesView: View {
    let entries: [JournalEntry]
    @State private var selectedEntry: JournalEntry?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Favorites")
                        .font(Theme.Typography.largeTitle)
                    Text("\(entries.count) starred entries")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                Spacer()
            }
            .padding()
            
            Divider()
            
            if entries.isEmpty {
                VStack(spacing: Theme.spacing) {
                    Image(systemName: "star")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.Colors.tertiaryText)
                    
                    Text("No favorite entries yet")
                        .font(Theme.Typography.title)
                    
                    Text("Mark entries as favorites to see them here")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.spacing) {
                        ForEach(entries) { entry in
                            EntryCard(
                                entry: entry,
                                isSelected: selectedEntry?.id == entry.id,
                                onTap: { selectedEntry = entry }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Theme.Colors.windowBackground)
    }
}