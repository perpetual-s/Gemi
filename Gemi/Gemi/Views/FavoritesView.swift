import SwiftUI

struct FavoritesView: View {
    let entries: [JournalEntry]
    
    var body: some View {
        VStack {
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
                                isSelected: false,
                                onTap: {}
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