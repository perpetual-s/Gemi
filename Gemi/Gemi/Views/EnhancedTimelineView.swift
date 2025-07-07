import SwiftUI

/// Enhanced timeline view with AI features
struct EnhancedTimelineView: View {
    @ObservedObject var journalStore: JournalStore
    @Binding var selectedEntry: JournalEntry?
    let onNewEntry: () -> Void
    var onEditEntry: ((JournalEntry) -> Void)? = nil
    
    @State private var groupedEntries: [Date: [JournalEntry]] = [:]
    @State private var showingAIInsights = false
    @State private var moodTrend: MoodTrend?
    @State private var selectedEntryForChat: JournalEntry?
    @State private var showingFloatingChat = false
    @State private var readingEntry: JournalEntry?
    @State private var showingReadingView = false
    
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
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ChatFloatingButton(showingChat: $showingFloatingChat)
                        .padding(Theme.largeSpacing)
                        .transition(.scale.combined(with: .opacity))
                }
            }
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
        .sheet(isPresented: $showingReadingView) {
            if let entry = readingEntry {
                EnhancedEntryReadingView(
                    entry: entry,
                    onEdit: {
                        showingReadingView = false
                        onEditEntry?(entry)
                    },
                    onDelete: {
                        showingReadingView = false
                        Task {
                            await journalStore.deleteEntry(entry)
                        }
                    },
                    onChat: {
                        showingReadingView = false
                        selectedEntryForChat = entry
                        showingFloatingChat = true
                    }
                )
                .frame(minWidth: 700, minHeight: 600)
            }
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
                .controlSize(.large)
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
            dateSectionHeader(for: date)
            entriesForDate(date)
        }
    }
    
    @ViewBuilder
    private func dateSectionHeader(for date: Date) -> some View {
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
    }
    
    @ViewBuilder
    private func entriesForDate(_ date: Date) -> some View {
        ForEach(groupedEntries[date] ?? []) { entry in
            EnhancedEntryCard(
                entry: entry,
                isSelected: selectedEntry?.id == entry.id,
                onTap: { selectedEntry = entry },
                onChat: { selectedEntryForChat = entry },
                onToggleFavorite: {
                    toggleFavorite(for: entry)
                },
                onEdit: {
                    onEditEntry?(entry)
                },
                onDelete: {
                    Task {
                        await journalStore.deleteEntry(entry)
                    }
                },
                onRead: {
                    readingEntry = entry
                    showingReadingView = true
                }
            )
        }
    }
    
    private func toggleFavorite(for entry: JournalEntry) {
        if let index = journalStore.entries.firstIndex(where: { $0.id == entry.id }) {
            // Update the entry
            let updatedEntry = journalStore.entries[index]
            updatedEntry.isFavorite.toggle()
            updatedEntry.modifiedAt = Date()
            
            // Update local state immediately for responsive UI
            journalStore.objectWillChange.send()
            
            Task {
                await journalStore.saveEntry(updatedEntry)
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
    let onToggleFavorite: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onRead: (() -> Void)? = nil
    
    @State private var isHovered = false
    @State private var showAIActions = false
    @State private var isExpanded = false
    @State private var showingReadingMode = false
    @State private var localIsFavorite: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content - restructured to fix star button
            VStack(alignment: .leading, spacing: 8) {
                // Header with proper button separation
                HStack {
                    Text(entry.displayTitle)
                        .font(Theme.Typography.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: Theme.spacing) {
                        // Interactive favorite button - now outside main button
                        Button(action: {
                            localIsFavorite.toggle()
                            onToggleFavorite()
                        }) {
                            Image(systemName: localIsFavorite ? "star.fill" : "star")
                                .font(.system(size: 16))
                                .foregroundColor(localIsFavorite ? .yellow : Theme.Colors.secondaryText)
                                .scaleEffect(localIsFavorite ? 1.1 : 1)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: localIsFavorite)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .help(localIsFavorite ? "Remove from favorites" : "Add to favorites")
                        
                        // Expand indicator
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.tertiaryText)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                        
                        Text(timeString)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                    }
                }
                
                // Make the rest of the card clickable (excluding star button)
                Button(action: {
                    // Open reading view if available, otherwise toggle expansion
                    if let onRead = onRead {
                        onRead()
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Content preview (expandable)
                        if !entry.content.isEmpty {
                            Text(entry.content)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .lineLimit(isExpanded ? nil : 2)
                                .animation(.easeInOut(duration: 0.2), value: isExpanded)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if onRead != nil {
                        if hovering {
                            NSCursor.pointingHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
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
            
            // Expanded actions
            if isExpanded {
                HStack(spacing: Theme.spacing) {
                    // Read in full view button
                    Button {
                        onRead?()
                    } label: {
                        Label("Read Full", systemImage: "book")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                    
                    // Chat about this entry
                    Button {
                        onChat()
                    } label: {
                        Label("Discuss with Gemi", systemImage: "bubble.left.and.bubble.right")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    // Edit button
                    Button {
                        onTap() // This triggers edit mode
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.spacing)
                .padding(.top, Theme.smallSpacing)
                .padding(.bottom, Theme.spacing)
                .background(Theme.Colors.cardBackground.opacity(0.5))
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .onAppear {
            localIsFavorite = entry.isFavorite
        }
        .onChange(of: entry.isFavorite) { _, newValue in
            localIsFavorite = newValue
        }
        .onHover { hovering in
            withAnimation(Theme.quickAnimation) {
                isHovered = hovering
                if !hovering {
                    showAIActions = false
                }
            }
        }
        .sheet(isPresented: $showingReadingMode) {
            ReadingModeView(entry: entry, onDismiss: {
                showingReadingMode = false
            }, onChat: {
                showingReadingMode = false
                onChat()
            })
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

// MARK: - Reading Mode View

struct ReadingModeView: View {
    let entry: JournalEntry
    let onDismiss: () -> Void
    let onChat: () -> Void
    
    @State private var showingShareMenu = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                    // Enhanced header with visual design
                    VStack(alignment: .leading, spacing: 16) {
                        // Close button at top
                        HStack {
                            Spacer()
                            Button(action: onDismiss) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Theme.Colors.tertiaryText)
                                    .background(Circle().fill(Color.white.opacity(0.8)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Title and metadata
                        VStack(alignment: .leading, spacing: 12) {
                            Text(entry.displayTitle)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 16) {
                                // Date
                                Label(entry.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.Colors.secondaryText)
                                
                                // Mood
                                if let mood = entry.mood {
                                    HStack(spacing: 4) {
                                        Text(mood.emoji)
                                            .font(.system(size: 16))
                                        Text(mood.rawValue.capitalized)
                                            .font(.system(size: 13))
                                            .foregroundColor(Theme.Colors.secondaryText)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Theme.Colors.cardBackground)
                                    )
                                }
                                
                                Spacer()
                                
                                // Reading time
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 12))
                                    Text("\(entry.readingTime) min")
                                        .font(.system(size: 13))
                                }
                                .foregroundColor(Theme.Colors.tertiaryText)
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                    .background(
                        LinearGradient(
                            colors: [Theme.Colors.cardBackground, Theme.Colors.windowBackground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Main content area
                    VStack(alignment: .leading, spacing: 24) {
                        // Content with better typography
                        Text(entry.content)
                            .font(.system(size: 17, weight: .regular, design: .default))
                            .lineSpacing(8)
                            .foregroundColor(.primary.opacity(0.9))
                            .textSelection(.enabled)
                            .padding(.horizontal, 30)
                            .padding(.top, 24)
                        
                        // Tags section
                        if !entry.tags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tags")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.Colors.tertiaryText)
                                    .textCase(.uppercase)
                                
                                HStack(spacing: 8) {
                                    ForEach(entry.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(Theme.Colors.primaryAccent.opacity(0.1))
                                            )
                                            .foregroundColor(Theme.Colors.primaryAccent)
                                    }
                                }
                            }
                            .padding(.horizontal, 30)
                        }
                        
                        // Action buttons
                        HStack(spacing: Theme.spacing) {
                            Button(action: onChat) {
                                Label("Discuss with Gemi", systemImage: "bubble.left.and.bubble.right")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            
                            Button(action: {
                                // Share functionality
                                showingShareMenu = true
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    }
                    .background(Theme.Colors.windowBackground)
                }
            }
        .frame(minWidth: 600, minHeight: 500)
        .background(Theme.Colors.windowBackground)
    }
}