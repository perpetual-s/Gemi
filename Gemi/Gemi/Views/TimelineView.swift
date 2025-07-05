import SwiftUI

struct TimelineView: View {
    let entries: [JournalEntry]
    @Binding var selectedEntry: JournalEntry?
    let onNewEntry: () -> Void
    
    @State private var groupedEntries: [Date: [JournalEntry]] = [:]
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.largeSpacing) {
                        ForEach(sortedDates, id: \.self) { date in
                            dateSection(for: date)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Theme.Colors.windowBackground)
        .onAppear {
            groupEntriesByDate()
        }
        .onChange(of: entries) { _ in
            groupEntriesByDate()
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Journal Timeline")
                    .font(Theme.Typography.largeTitle)
                
                Text("\(entries.count) entries")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            Spacer()
            
            Button(action: onNewEntry) {
                Label("New Entry", systemImage: "plus")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: Theme.spacing) {
            Image(systemName: "book.closed")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.tertiaryText)
            
            Text("No journal entries yet")
                .font(Theme.Typography.title)
            
            Text("Start writing to capture your thoughts and memories")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
            
            Button(action: onNewEntry) {
                Label("Create Your First Entry", systemImage: "plus.circle.fill")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func dateSection(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(dateHeader(for: date))
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.secondaryText)
            
            ForEach(groupedEntries[date] ?? []) { entry in
                EntryCard(
                    entry: entry,
                    isSelected: selectedEntry?.id == entry.id,
                    onTap: { selectedEntry = entry }
                )
            }
        }
    }
    
    private var sortedDates: [Date] {
        groupedEntries.keys.sorted(by: >)
    }
    
    private func groupEntriesByDate() {
        let calendar = Calendar.current
        groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }
    }
    
    private func dateHeader(for date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

struct EntryCard: View {
    let entry: JournalEntry
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.displayTitle)
                        .font(Theme.Typography.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    Text(timeString)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                }
                
                if !entry.preview.isEmpty {
                    Text(entry.preview)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .lineLimit(2)
                }
                
                if !entry.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(entry.tags, id: \.self) { tag in
                            TagView(tag: tag)
                        }
                    }
                }
                
                HStack {
                    if let mood = entry.mood {
                        Label(mood, systemImage: "face.smiling")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                    }
                    
                    Spacer()
                    
                    Label("\(entry.wordCount) words", systemImage: "text.alignleft")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                    
                    Label("\(entry.readingTime) min", systemImage: "clock")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 0)
                    )
            )
            .shadow(color: shadowColor, radius: isHovered ? 4 : 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.quickAnimation) {
                isHovered = hovering
            }
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: entry.createdAt)
    }
    
    private var cardBackgroundColor: Color {
        if isSelected {
            return Theme.Colors.selectedBackground
        } else {
            return Theme.Colors.cardBackground
        }
    }
    
    private var borderColor: Color {
        isSelected ? Theme.Colors.primaryAccent : Color.clear
    }
    
    private var shadowColor: Color {
        Color.black.opacity(isHovered ? 0.1 : 0.05)
    }
}

struct TagView: View {
    let tag: String
    
    var body: some View {
        Text("#\(tag)")
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.primaryAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.Colors.primaryAccent.opacity(0.1))
            .cornerRadius(4)
    }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView(
            entries: JournalEntry.mockEntries(),
            selectedEntry: .constant(nil),
            onNewEntry: {}
        )
    }
}