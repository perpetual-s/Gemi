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
    @State private var readingEntry: JournalEntry?
    
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
                
                GeometryReader { geometry in
                    ScrollView(showsIndicators: false) {
                        if groupedEntries.isEmpty {
                            // Empty state - centered vertically
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                    .frame(maxHeight: .infinity)
                                
                                // Beautiful empty state matching design language
                                VStack(spacing: Theme.largeSpacing) {
                                    // Icon with gradient background
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Theme.Colors.primaryAccent.opacity(0.1),
                                                        Theme.Colors.primaryAccent.opacity(0.05)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 120, height: 120)
                                        
                                        Image(systemName: "calendar")
                                            .font(.system(size: 56))
                                            .foregroundColor(Theme.Colors.primaryAccent)
                                    }
                                    
                                    VStack(spacing: Theme.spacing) {
                                        Text("No journal entries yet")
                                            .font(Theme.Typography.title)
                                            .foregroundColor(.primary)
                                        
                                        Text("Start documenting your journey.\nYour timeline will appear here.")
                                            .font(Theme.Typography.body)
                                            .foregroundColor(Theme.Colors.secondaryText)
                                            .multilineTextAlignment(.center)
                                            .frame(maxWidth: 400)
                                        
                                        Button(action: onNewEntry) {
                                            Label("Create Your First Entry", systemImage: "plus.circle.fill")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.large)
                                        .padding(.top, Theme.spacing)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                                
                                Spacer(minLength: 0)
                                    .frame(maxHeight: .infinity)
                            }
                            .frame(minHeight: geometry.size.height)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                        } else {
                            // Entries - aligned from top without centering
                            LazyVStack(alignment: .leading, spacing: Theme.largeSpacing) {
                                ForEach(sortedDates, id: \.self) { date in
                                    dateSection(for: date)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                        }
                    }
                    .scrollIndicators(.never)
                }
            }
            .background(Theme.Colors.windowBackground)
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
            TimelineInsightsCard(entries: journalStore.entries)
        }
        .sheet(isPresented: Binding(
            get: { selectedEntryForChat != nil },
            set: { newValue in
                if !newValue {
                    selectedEntryForChat = nil
                }
            }
        )) {
            if let entry = selectedEntryForChat {
                // Entry-specific chat
                ChatSheet(journalEntry: entry)
            }
        }
        .sheet(item: $readingEntry) { entry in
            // Ensure the entry is captured properly
            EnhancedEntryReadingView(
                entry: entry,
                onEdit: {
                    readingEntry = nil
                    onEditEntry?(entry)
                },
                onDelete: {
                    readingEntry = nil
                    Task {
                        await journalStore.deleteEntry(entry)
                    }
                },
                onChat: {
                    readingEntry = nil
                    selectedEntryForChat = entry
                }
            )
            .frame(minWidth: 700, idealWidth: 800, minHeight: 600, idealHeight: 700)
            .background(Theme.Colors.windowBackground)
        }
        .onKeyPress(.return) {
            // Enter/Return key to open selected entry for reading
            if let selected = selectedEntry {
                readingEntry = selected
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.space) {
            // Space key to open selected entry for reading (alternative)
            if let selected = selectedEntry {
                readingEntry = selected
                return .handled
            }
            return .ignored
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Journal Timeline")
                    .font(Theme.Typography.sectionHeader)
                
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
            
            HStack(spacing: 12) {
                // AI Insights button with modern design
                Button {
                    showingAIInsights = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "brain")
                            .font(.system(size: 14, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                        Text("AI Insights")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            // Subtle gradient background
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(NSColor.controlBackgroundColor),
                                            Color(NSColor.controlBackgroundColor).opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Glass effect overlay
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.1),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.primary.opacity(0.1),
                                        Color.primary.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(ModernButtonStyle())
                
                // New Entry button with prominent modern design
                Button(action: onNewEntry) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("New Entry")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            // Primary gradient
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Theme.Colors.primaryAccent,
                                            Theme.Colors.primaryAccent.opacity(0.9)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Glass shimmer
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.05),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .center
                                    )
                                )
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Theme.Colors.primaryAccent.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(ModernButtonStyle())
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
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
            PremiumEntryCard(
                entry: entry,
                isSelected: selectedEntry?.id == entry.id,
                onSelect: { 
                    // Select the entry
                    selectedEntry = entry
                    readingEntry = entry
                },
                onEdit: {
                    onEditEntry?(entry)
                },
                onDelete: {
                    Task {
                        await journalStore.deleteEntry(entry)
                    }
                },
                onChat: {
                    selectedEntryForChat = entry
                },
                onToggleFavorite: {
                    toggleFavorite(for: entry)
                }
            )
        }
    }
    
    private func toggleFavorite(for entry: JournalEntry) {
        Task {
            // Toggle the favorite status
            entry.isFavorite.toggle()
            entry.modifiedAt = Date()
            
            // Update in database
            await journalStore.updateEntry(entry)
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
        case .angry:
            return "Strong emotions deserve attention. Express them safely through writing."
        case .accomplished:
            return "Celebrate your achievements! You've earned this feeling."
        }
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
        case .frustrated, .angry:
            return .red
        case .neutral:
            return .gray
        case .accomplished:
            return .indigo
        }
    }
}

// MARK: - Supporting Types

struct MoodTrend {
    let dominantMood: Mood
    let summary: String
    let recommendation: String
}

// MARK: - Enhanced Insight Card Component

struct EnhancedInsightCard<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content
                .padding(.leading, 24)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Modern Button Style

struct ModernButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : (isHovered ? 1.02 : 1.0))
            .animation(Theme.microInteraction, value: configuration.isPressed)
            .animation(Theme.gentleSpring, value: isHovered)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}
