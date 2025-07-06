import SwiftUI

/// Enhanced timeline view with AI features
struct EnhancedTimelineView: View {
    @ObservedObject var journalStore: JournalStore
    @Binding var selectedEntry: JournalEntry?
    let onNewEntry: () -> Void
    
    @State private var groupedEntries: [Date: [JournalEntry]] = [:]
    @State private var showingAIInsights = false
    @State private var moodTrend: MoodTrend?
    @State private var selectedEntryForChat: JournalEntry?
    @State private var showingFloatingChat = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                header
                
                // AI Insights Banner
                if let trend = moodTrend {
                    AIInsightsBanner(trend: trend) {
                        showingAIInsights = true
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Divider()
                
                if journalStore.entries.isEmpty {
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
            
            // Floating Chat Button
            ChatFloatingButton(showingChat: $showingFloatingChat)
                .padding(Theme.largeSpacing)
                .transition(.scale.combined(with: .opacity))
        }
        .onAppear {
            groupEntriesByDate()
            analyzeMoodTrend()
        }
        .onChange(of: journalStore.entries) {
            groupEntriesByDate()
            analyzeMoodTrend()
        }
        .sheet(isPresented: $showingAIInsights) {
            AIInsightsView(entries: journalStore.entries)
        }
        .sheet(item: $selectedEntryForChat) { entry in
            ChatSheet(journalEntry: entry)
        }
        .sheet(isPresented: $showingFloatingChat) {
            GemiChatView()
                .frame(width: 900, height: 600)
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Journal Timeline")
                    .font(Theme.Typography.largeTitle)
                
                HStack(spacing: Theme.smallSpacing) {
                    Text("\(journalStore.entries.count) entries")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    if let trend = moodTrend {
                        Text("•")
                            .foregroundColor(Theme.Colors.tertiaryText)
                        
                        Label(trend.summary, systemImage: "sparkles")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primaryAccent)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: Theme.spacing) {
                Button {
                    showingAIInsights = true
                } label: {
                    Label("AI Insights", systemImage: "brain")
                }
                .buttonStyle(.bordered)
                
                Button(action: onNewEntry) {
                    Label("New Entry", systemImage: "plus")
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
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
            
            VStack(spacing: Theme.spacing) {
                Button(action: onNewEntry) {
                    Label("Create Your First Entry", systemImage: "plus.circle.fill")
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                
                Button {
                    showingFloatingChat = true
                } label: {
                    Label("Talk to Gemi", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func dateSection(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack {
                Text(dateHeader(for: date))
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Spacer()
                
                // Daily mood indicator
                if let dailyMood = getDailyMood(for: date) {
                    Text(dailyMood.emoji)
                        .font(.title3)
                }
            }
            
            ForEach(groupedEntries[date] ?? []) { entry in
                EnhancedEntryCard(
                    entry: entry,
                    isSelected: selectedEntry?.id == entry.id,
                    onTap: { selectedEntry = entry },
                    onChat: { selectedEntryForChat = entry }
                )
            }
        }
    }
    
    private var sortedDates: [Date] {
        groupedEntries.keys.sorted(by: >)
    }
    
    private func groupEntriesByDate() {
        let calendar = Calendar.current
        groupedEntries = Dictionary(grouping: journalStore.entries) { entry in
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
    
    private func getDailyMood(for date: Date) -> Mood? {
        let entries = groupedEntries[date] ?? []
        let moods = entries.compactMap { $0.mood }
        
        // Return most frequent mood for the day
        let moodCounts = Dictionary(grouping: moods, by: { $0 }).mapValues { $0.count }
        return moodCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private func analyzeMoodTrend() {
        let recentEntries = Array(journalStore.entries.prefix(7))
        let moods = recentEntries.compactMap { $0.mood }
        
        guard !moods.isEmpty else { return }
        
        // Simple mood trend analysis
        let moodCounts = Dictionary(grouping: moods, by: { $0 }).mapValues { $0.count }
        if let dominantMood = moodCounts.max(by: { $0.value < $1.value })?.key {
            moodTrend = MoodTrend(
                dominantMood: dominantMood,
                summary: "Mostly \(dominantMood.rawValue.lowercased()) this week",
                recommendation: generateRecommendation(for: dominantMood)
            )
        }
    }
    
    private func generateRecommendation(for mood: Mood) -> String {
        switch mood {
        case .happy, .excited:
            return "You're doing great! Keep nurturing what brings you joy."
        case .peaceful, .grateful:
            return "Your peaceful energy is wonderful. Consider sharing it with others."
        case .anxious:
            return "Take some deep breaths. Would you like to explore what's on your mind?"
        case .sad, .frustrated:
            return "It's okay to feel this way. Writing can help process these emotions."
        case .neutral:
            return "A balanced state. What small joy could brighten your day?"
        default:
            return "Every emotion is valid. Keep exploring through writing."
        }
    }
}

// MARK: - Enhanced Entry Card

struct EnhancedEntryCard: View {
    let entry: JournalEntry
    let isSelected: Bool
    let onTap: () -> Void
    let onChat: () -> Void
    
    @State private var isHovered = false
    @State private var showAIActions = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(entry.displayTitle)
                        .font(Theme.Typography.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if entry.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        
                        if isHovered || showAIActions {
                            AIQuickActions(
                                onChat: {
                                    onChat()
                                },
                                onAnalyze: {
                                    // TODO: Quick analysis
                                }
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        Text(timeString)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                    }
                }
                
                // Content preview
                if !entry.preview.isEmpty {
                    Text(entry.preview)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .lineLimit(2)
                }
                
                // Tags
                if !entry.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(entry.tags, id: \.self) { tag in
                            TagView(tag: tag)
                        }
                    }
                }
                
                // Footer with mood and stats
                HStack {
                    if let mood = entry.mood {
                        MoodBadge(mood: mood)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: Theme.spacing) {
                        Label("\(entry.wordCount) words", systemImage: "text.alignleft")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                        
                        Label("\(entry.readingTime) min", systemImage: "clock")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                    }
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
                if !hovering {
                    showAIActions = false
                }
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

// MARK: - AI Components

struct AIInsightsBanner: View {
    let trend: MoodTrend
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(Theme.Colors.primaryAccent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(trend.summary)
                        .font(Theme.Typography.headline)
                    Text(trend.recommendation)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        Theme.Colors.primaryAccent.opacity(0.1),
                        Theme.Colors.primaryAccent.opacity(0.05)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .buttonStyle(.plain)
    }
}

struct AIQuickActions: View {
    let onChat: () -> Void
    let onAnalyze: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Button(action: onChat) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(Theme.Colors.primaryAccent)
            .help("Talk to Gemi about this entry")
            
            Button(action: onAnalyze) {
                Image(systemName: "brain")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(Theme.Colors.primaryAccent)
            .help("Get AI insights")
        }
    }
}

struct MoodBadge: View {
    let mood: Mood
    
    var body: some View {
        Label {
            Text(mood.rawValue)
                .font(Theme.Typography.caption)
        } icon: {
            Text(mood.emoji)
                .font(.callout)
        }
        .foregroundColor(moodColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(moodColor.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var moodColor: Color {
        switch mood {
        case .happy, .excited:
            return .green
        case .peaceful, .grateful:
            return .blue
        case .anxious:
            return .orange
        case .sad:
            return .purple
        case .frustrated:
            return .red
        case .neutral:
            return .gray
        default:
            return Theme.Colors.primaryAccent
        }
    }
}

// MARK: - Supporting Types

struct MoodTrend {
    let dominantMood: Mood
    let summary: String
    let recommendation: String
}