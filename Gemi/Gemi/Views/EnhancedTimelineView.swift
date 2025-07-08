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
    @State private var selectedReflectionPrompt: String?
    
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
            if let prompt = selectedReflectionPrompt {
                EnhancedChatSheet(journalEntry: entry, reflectionPrompt: prompt)
                    .onDisappear {
                        selectedReflectionPrompt = nil
                    }
            } else {
                ChatSheet(journalEntry: entry)
            }
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
        .onKeyPress(.return) {
            // Enter/Return key to open selected entry for reading
            if let selected = selectedEntry {
                readingEntry = selected
                showingReadingView = true
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.space) {
            // Space key to open selected entry for reading (alternative)
            if let selected = selectedEntry {
                readingEntry = selected
                showingReadingView = true
                return .handled
            }
            return .ignored
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
        EmptyStateView()
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
            PremiumEntryCard(
                entry: entry,
                isSelected: selectedEntry?.id == entry.id,
                onSelect: { 
                    // Select the entry
                    selectedEntry = entry
                    readingEntry = entry
                    showingReadingView = true
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
                    showingFloatingChat = true
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
    @Binding var selectedReflectionPrompt: String?
    
    @State private var showingShareMenu = false
    @State private var showingAIInsights = false
    @State private var aiSummary: String?
    @State private var aiKeyPoints: [String] = []
    @State private var aiSuggestedPrompts: [String] = []
    @State private var isAnalyzing = false
    @State private var selectedPrompt: String?
    @State private var hasGeneratedInsights = false
    
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
                
                // AI Insights Toggle Button
                HStack {
                    Button(action: {
                        if !hasGeneratedInsights && !isAnalyzing {
                            generateAIInsights()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingAIInsights.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isAnalyzing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: showingAIInsights ? "sparkles.rectangle.stack.fill" : "sparkles")
                                    .font(.system(size: 16))
                                    .symbolRenderingMode(.hierarchical)
                            }
                            
                            Text(showingAIInsights ? "Hide AI Insights" : "Generate AI Insights")
                                .font(.system(size: 14, weight: .medium))
                            
                            if showingAIInsights && hasGeneratedInsights {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                            }
                        }
                        .foregroundColor(showingAIInsights ? .white : Theme.Colors.primaryAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(showingAIInsights ? Theme.Colors.primaryAccent : Theme.Colors.primaryAccent.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Theme.Colors.primaryAccent, lineWidth: showingAIInsights ? 0 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isAnalyzing)
                    
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                // AI Insights Section
                if showingAIInsights && hasGeneratedInsights {
                    VStack(alignment: .leading, spacing: 20) {
                        // Summary Card
                        if let summary = aiSummary {
                            EnhancedInsightCard(
                                icon: "text.quote",
                                title: "AI Summary",
                                color: Theme.Colors.primaryAccent
                            ) {
                                Text(summary)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary.opacity(0.9))
                                    .lineSpacing(4)
                            }
                        }
                        
                        // Key Themes Card
                        if !aiKeyPoints.isEmpty {
                            EnhancedInsightCard(
                                icon: "lightbulb.fill",
                                title: "Key Themes",
                                color: .orange
                            ) {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(aiKeyPoints.enumerated()), id: \.offset) { index, point in
                                        HStack(alignment: .top, spacing: 12) {
                                            Text("\(index + 1)")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white)
                                                .frame(width: 20, height: 20)
                                                .background(Circle().fill(Color.orange))
                                            
                                            Text(point)
                                                .font(.system(size: 14))
                                                .foregroundColor(.primary.opacity(0.85))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Reflection Prompts Card
                        if !aiSuggestedPrompts.isEmpty {
                            EnhancedInsightCard(
                                icon: "bubble.left.and.bubble.right.fill",
                                title: "Reflection Prompts",
                                color: .purple
                            ) {
                                VStack(spacing: 10) {
                                    ForEach(aiSuggestedPrompts, id: \.self) { prompt in
                                        Button {
                                            selectedPrompt = prompt
                                            selectedReflectionPrompt = prompt
                                            onChat()
                                        } label: {
                                            HStack {
                                                Text(prompt)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.primary)
                                                    .multilineTextAlignment(.leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "arrow.right.circle.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(.purple)
                                            }
                                            .padding(12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.purple.opacity(0.08))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 20)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                
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
        .onAppear {
            // Automatically generate insights when opening
            if !hasGeneratedInsights && !isAnalyzing {
                generateAIInsights()
            }
        }
    }
    
    // MARK: - AI Methods
    
    private func generateAIInsights() {
        isAnalyzing = true
        showingAIInsights = true
        
        Task {
            do {
                // Use the real Gemma3n API through GemiAICoordinator
                let insights = try await GemiAICoordinator.shared.generateInsights(for: entry)
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.aiSummary = insights.summary
                        self.aiKeyPoints = insights.keyPoints
                        self.aiSuggestedPrompts = insights.prompts
                        self.isAnalyzing = false
                        self.hasGeneratedInsights = true
                    }
                }
            } catch {
                // Handle errors gracefully with fallback content
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.aiSummary = "Your entry captures a meaningful moment. While I couldn't generate specific insights right now, your reflection shows thoughtful self-awareness."
                        self.aiKeyPoints = [
                            "Personal reflection and self-awareness demonstrated",
                            "Emotional processing through journaling",
                            "Growth mindset evident in your writing"
                        ]
                        self.aiSuggestedPrompts = [
                            "What emotions are most present in this entry, and what might they be telling you?",
                            "How does this experience connect to your personal values or goals?",
                            "What would you tell a friend going through something similar?"
                        ]
                        self.isAnalyzing = false
                        self.hasGeneratedInsights = true
                    }
                }
            }
        }
    }
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

// MARK: - Enhanced Chat Sheet with Prompt

struct EnhancedChatSheet: View {
    let journalEntry: JournalEntry
    let reflectionPrompt: String?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var isInitialized = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Talking about your entry")
                        .font(Theme.Typography.headline)
                    Text(journalEntry.createdAt, style: .date)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.spacing)
            
            Divider()
            
            // Chat view
            GemiChatView(contextEntry: journalEntry)
        }
        .frame(minWidth: 600, idealWidth: 700, maxWidth: 900, minHeight: 400, idealHeight: 500, maxHeight: 700)
        .background(Theme.Colors.windowBackground)
        .onAppear {
            if !isInitialized {
                initializeChat()
                isInitialized = true
            }
        }
    }
    
    private func initializeChat() {
        Task {
            // Create memories specific to this entry
            let entryMemory = Memory(
                content: String(journalEntry.content.prefix(500)) + "...",
                sourceEntryID: journalEntry.id
            )
            
            // Use the reflection prompt if provided, otherwise use context
            let initialMessage: String
            if let prompt = reflectionPrompt {
                initialMessage = """
                I'd like to reflect on my journal entry from \(journalEntry.createdAt.formatted(date: .abbreviated, time: .omitted)).
                
                \(prompt)
                
                Context from my entry: "\(journalEntry.content.prefix(200))..."
                """
            } else {
                let context = extractContext(from: journalEntry)
                initialMessage = """
                I'd like to reflect on my journal entry from \(journalEntry.createdAt.formatted(date: .abbreviated, time: .omitted)). \
                \(context)
                """
            }
            
            await chatViewModel.sendMessage(initialMessage, withMemories: [entryMemory])
        }
    }
    
    private func extractContext(from entry: JournalEntry) -> String {
        var context = ""
        
        if let mood = entry.mood {
            context += "I was feeling \(mood). "
        }
        
        if !entry.tags.isEmpty {
            context += "I wrote about \(entry.tags.joined(separator: ", ")). "
        }
        
        // Extract first meaningful sentence
        let sentences = entry.content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if let firstSentence = sentences.first {
            context += "Here's what I wrote: \"\(firstSentence)...\""
        }
        
        return context
    }
}