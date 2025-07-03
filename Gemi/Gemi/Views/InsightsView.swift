//
//  InsightsView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI
import Charts

/// InsightsView provides AI-powered patterns and analysis of journal entries
struct InsightsView: View {
    @Environment(JournalStore.self) private var journalStore
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedTimeRange: TimeRange = .month
    @State private var showingMemoryManager = false
    @State private var isAnalyzing = false
    @State private var insights: JournalInsights?
    @State private var personalInsights: [PersonalInsight] = []
    @State private var topics: [Topic] = []
    @State private var moodData: [MoodDataPoint] = []
    @State private var ollamaStatus: String = "Checking..."
    
    private let ollamaService = OllamaService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                // Header
                headerSection
                
                // Quick Stats
                quickStatsSection
                
                // Mood Patterns
                moodPatternsSection
                
                // Writing Patterns
                writingPatternsSection
                
                // Topics Word Cloud
                if !topics.isEmpty {
                    topicsSection
                }
                
                // Writing Calendar
                writingCalendarSection
                
                // AI Insights
                aiInsightsSection
                
                // Memory Management
                memoryManagementSection
            }
            .padding(DesignSystem.Spacing.extraLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.backgroundPrimary)
        .task {
            await analyzeJournal()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                    Text("Insights")
                        .font(DesignSystem.Typography.display)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Text("Discover patterns in your journaling journey")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Time range picker
                HStack(spacing: DesignSystem.Spacing.tiny) {
                    Text("Time Range:")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                }
            }
            
            Divider()
                .opacity(0.3)
        }
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            StatCard(
                title: "Total Entries",
                value: "\(journalStore.entries.count)",
                icon: "book.pages.fill",
                color: DesignSystem.Colors.primary
            )
            
            StatCard(
                title: "Writing Streak",
                value: "\(calculateStreak()) days",
                icon: "flame.fill",
                color: .orange
            )
            
            StatCard(
                title: "Avg. Words/Entry",
                value: "\(calculateAverageWords())",
                icon: "text.word.spacing",
                color: .purple
            )
            
            StatCard(
                title: "Most Active Hour",
                value: mostActiveHour(),
                icon: "clock.fill",
                color: .teal
            )
        }
    }
    
    // MARK: - Mood Patterns Section
    
    private var moodPatternsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Mood Patterns")
                .font(DesignSystem.Typography.title2)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            if !moodData.isEmpty {
                Chart(moodData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Mood", dataPoint.moodScore)
                    )
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Mood", dataPoint.moodScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.primary.opacity(0.3), DesignSystem.Colors.primary.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 200)
                .chartYScale(domain: 0...5)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text(moodLabel(for: intValue))
                                    .font(DesignSystem.Typography.caption2)
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                        .fill(DesignSystem.Colors.backgroundSecondary)
                )
            } else {
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                    .fill(DesignSystem.Colors.backgroundSecondary)
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 40))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                            Text("Add mood to entries to see patterns")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }
                    )
            }
        }
    }
    
    // MARK: - Writing Patterns Section
    
    private var writingPatternsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Writing Patterns")
                .font(DesignSystem.Typography.title2)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            HStack(spacing: DesignSystem.Spacing.medium) {
                // Writing frequency
                InsightCard(
                    title: "Most Productive Day",
                    description: mostProductiveDay(),
                    icon: "calendar.circle.fill",
                    color: .indigo
                )
                
                // Topics
                InsightCard(
                    title: "Common Topics",
                    description: topics.prefix(3).map { $0.name }.joined(separator: ", "),
                    icon: "tag.circle.fill",
                    color: .pink
                )
            }
        }
    }
    
    // MARK: - AI Insights Section
    
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("AI-Powered Insights")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button(action: { Task { await analyzeJournal() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(DesignSystem.Typography.callout)
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzing)
            }
            
            if isAnalyzing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing your journal entries...")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.large)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                        .fill(DesignSystem.Colors.backgroundSecondary)
                )
            } else if !personalInsights.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    ForEach(personalInsights) { insight in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
                            Image(systemName: insight.type.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(insight.type.color)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                                Text(insight.title)
                                    .font(DesignSystem.Typography.callout)
                                    .fontWeight(.medium)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                
                                Text(insight.description)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                HStack {
                                    Text("Confidence: \(Int(insight.confidence * 100))%")
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    
                                    Spacer()
                                    
                                    Text(insight.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                }
                            }
                        }
                        .padding(DesignSystem.Spacing.large)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                                .fill(DesignSystem.Colors.backgroundSecondary)
                        )
                    }
                }
            } else if insights != nil {
                Text("No insights available. Write more entries to see patterns.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.large)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                            .fill(DesignSystem.Colors.backgroundSecondary)
                    )
            }
        }
    }
    
    // MARK: - Memory Management Section
    
    private var memoryManagementSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                    Text("Memory Management")
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Text("Control what Gemi remembers about your journey")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Button(action: { showingMemoryManager = true }) {
                    Label("Manage", systemImage: "brain.head.profile")
                        .font(DesignSystem.Typography.callout)
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Memory preview
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                .fill(DesignSystem.Colors.backgroundSecondary)
                .frame(height: 100)
                .overlay(
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 30))
                            .foregroundStyle(DesignSystem.Colors.primary.opacity(0.3))
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                            Text("12 memories stored")
                                .font(DesignSystem.Typography.callout)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            
                            Text("Last updated today")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.large)
                )
        }
        .sheet(isPresented: $showingMemoryManager) {
            MemoryManagementView()
        }
    }
    
    // MARK: - Helper Methods
    
    private func analyzeJournal() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Check Ollama status
        let isOllamaRunning = await ollamaService.checkOllamaStatus()
        if !isOllamaRunning {
            ollamaStatus = "Ollama not running. Please start Ollama to enable AI insights."
            return
        }
        
        // Filter entries by time range
        let filteredEntries = filterEntriesByTimeRange(journalStore.entries)
        guard !filteredEntries.isEmpty else {
            insights = JournalInsights(patterns: [])
            return
        }
        
        // Generate mood data
        moodData = generateMoodData(from: filteredEntries)
        
        do {
            // Extract topics
            if filteredEntries.count >= 3 {
                let entriesText = filteredEntries.prefix(20).map { $0.content }
                topics = try await ollamaService.extractTopics(entries: entriesText)
            }
            
            // Generate personalized insights
            if filteredEntries.count >= 5 {
                personalInsights = try await ollamaService.generateInsights(entries: Array(filteredEntries.prefix(20)))
            }
            
            // Basic pattern analysis (fallback)
            var patterns: [String] = []
            
            // Writing frequency pattern
            let dayFrequency = Dictionary(grouping: filteredEntries) { entry in
                Calendar.current.component(.weekday, from: entry.createdAt)
            }
            if let mostFrequentDay = dayFrequency.max(by: { $0.value.count < $1.value.count }) {
                let dayName = Calendar.current.weekdaySymbols[mostFrequentDay.key - 1]
                patterns.append("You tend to write more on \(dayName)s")
            }
            
            // Time of day pattern
            let hourFrequency = Dictionary(grouping: filteredEntries) { entry in
                Calendar.current.component(.hour, from: entry.createdAt)
            }
            if let mostFrequentHour = hourFrequency.max(by: { $0.value.count < $1.value.count }) {
                let timeDescription = mostFrequentHour.key < 12 ? "mornings" : (mostFrequentHour.key < 17 ? "afternoons" : "evenings")
                patterns.append("You're most active in the \(timeDescription)")
            }
            
            insights = JournalInsights(patterns: patterns)
            
        } catch {
            print("AI analysis failed: \(error)")
            insights = JournalInsights(patterns: ["AI analysis unavailable. Please check Ollama connection."])
        }
    }
    
    private func calculateStreak() -> Int {
        // Simple streak calculation
        var streak = 0
        let calendar = Calendar.current
        var checkDate = Date()
        
        for _ in 0..<365 {
            let hasEntry = journalStore.entries.contains { entry in
                calendar.isDate(entry.createdAt, inSameDayAs: checkDate)
            }
            
            if hasEntry {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func calculateAverageWords() -> Int {
        guard !journalStore.entries.isEmpty else { return 0 }
        let totalWords = journalStore.entries.reduce(0) { $0 + $1.content.split(separator: " ").count }
        return totalWords / journalStore.entries.count
    }
    
    private func mostActiveHour() -> String {
        // Find most common hour
        let hours = journalStore.entries.map { Calendar.current.component(.hour, from: $0.createdAt) }
        let mostCommon = Dictionary(grouping: hours, by: { $0 })
            .sorted { $0.value.count > $1.value.count }
            .first?.key ?? 0
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: Calendar.current.date(bySettingHour: mostCommon, minute: 0, second: 0, of: Date())!)
    }
    
    private func mostProductiveDay() -> String {
        let days = journalStore.entries.map { Calendar.current.component(.weekday, from: $0.createdAt) }
        let mostCommon = Dictionary(grouping: days, by: { $0 })
            .sorted { $0.value.count > $1.value.count }
            .first?.key ?? 1
        
        return Calendar.current.weekdaySymbols[mostCommon - 1]
    }
    
    // MARK: - Topics Section
    
    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Topics & Themes")
                .font(DesignSystem.Typography.title2)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            // Simple word cloud visualization
            InsightsFlowLayout(spacing: DesignSystem.Spacing.small) {
                ForEach(topics.prefix(15)) { topic in
                    Text(topic.name)
                        .font(.system(size: CGFloat(12 + topic.frequency * 2)))
                        .fontWeight(topic.frequency > 5 ? .medium : .regular)
                        .foregroundStyle(topicColor(for: topic.frequency))
                        .padding(.horizontal, DesignSystem.Spacing.small)
                        .padding(.vertical, DesignSystem.Spacing.tiny)
                        .background(
                            Capsule()
                                .fill(topicColor(for: topic.frequency).opacity(0.1))
                        )
                }
            }
            .padding(DesignSystem.Spacing.large)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                    .fill(DesignSystem.Colors.backgroundSecondary)
            )
        }
    }
    
    // MARK: - Writing Calendar Section
    
    private var writingCalendarSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Writing Calendar")
                .font(DesignSystem.Typography.title2)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            // Simple calendar heatmap
            CalendarHeatmap(entries: journalStore.entries)
                .frame(height: 150)
                .padding(DesignSystem.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                        .fill(DesignSystem.Colors.backgroundSecondary)
                )
        }
    }
    
    // MARK: - Helper Methods
    
    private func filterEntriesByTimeRange(_ entries: [JournalEntry]) -> [JournalEntry] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeRange {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return entries.filter { $0.createdAt >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return entries.filter { $0.createdAt >= monthAgo }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return entries.filter { $0.createdAt >= yearAgo }
        case .all:
            return entries
        }
    }
    
    private func generateMoodData(from entries: [JournalEntry]) -> [MoodDataPoint] {
        let entriesWithMood = entries.filter { $0.mood != nil }
        
        return entriesWithMood.map { entry in
            let moodScore: Double = {
                switch entry.mood?.lowercased() {
                case "very happy", "excited", "joyful": return 5.0
                case "happy", "good", "content": return 4.0
                case "neutral", "okay", "fine": return 3.0
                case "sad", "down", "tired": return 2.0
                case "very sad", "depressed", "anxious": return 1.0
                default: return 3.0
                }
            }()
            
            return MoodDataPoint(date: entry.createdAt, moodScore: moodScore)
        }.sorted { $0.date < $1.date }
    }
    
    private func moodLabel(for score: Int) -> String {
        switch score {
        case 5: return "😊"
        case 4: return "🙂"
        case 3: return "😐"
        case 2: return "😔"
        case 1: return "😢"
        default: return ""
        }
    }
    
    private func topicColor(for frequency: Int) -> Color {
        switch frequency {
        case 8...10: return DesignSystem.Colors.primary
        case 5...7: return .purple
        case 3...4: return .blue
        default: return DesignSystem.Colors.textSecondary
        }
    }
}

// MARK: - Supporting Types

enum TimeRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All Time"
}

struct JournalInsights {
    let patterns: [String]
}

struct MoodDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let moodScore: Double
}

// MARK: - Components

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            Text(value)
                .font(DesignSystem.Typography.title1)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Text(title)
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.large)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                .fill(DesignSystem.Colors.backgroundSecondary)
        )
    }
}

struct InsightCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                Text(title)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.large)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                .fill(DesignSystem.Colors.backgroundSecondary)
        )
    }
}

// MARK: - InsightsFlowLayout

struct InsightsFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxX: CGFloat = 0
            
            for subview in subviews {
                let dimensions = subview.dimensions(in: ProposedViewSize(width: nil, height: nil))
                
                if currentX + dimensions.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: dimensions.width, height: dimensions.height))
                lineHeight = max(lineHeight, dimensions.height)
                currentX += dimensions.width + spacing
                maxX = max(maxX, currentX - spacing)
            }
            
            size = CGSize(width: maxX, height: currentY + lineHeight)
        }
    }
}

// MARK: - CalendarHeatmap

struct CalendarHeatmap: View {
    let entries: [JournalEntry]
    
    private let columns = 7
    private let cellSize: CGFloat = 15
    private let cellSpacing: CGFloat = 2
    
    var body: some View {
        GeometryReader { geometry in
            let weeks = calculateWeeks()
            let maxEntriesPerDay = weeks.flatMap { $0 }.compactMap { $0?.count }.max() ?? 1
            
            HStack(alignment: .top, spacing: cellSpacing) {
                // Weekday labels
                VStack(spacing: cellSpacing) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 10))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .frame(width: cellSize, height: cellSize)
                    }
                }
                
                // Calendar cells
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<weeks.count, id: \.self) { weekIndex in
                            VStack(spacing: cellSpacing) {
                                ForEach(0..<7) { dayIndex in
                                    if let dayData = weeks[weekIndex][dayIndex] {
                                        CalendarCell(
                                            count: dayData.count,
                                            maxCount: maxEntriesPerDay,
                                            date: dayData.date
                                        )
                                    } else {
                                        Color.clear
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func calculateWeeks() -> [[DayData?]] {
        let calendar = Calendar.current
        let today = Date()
        let twelveWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -12, to: today)!
        
        // Group entries by date
        let entriesByDate = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }
        
        var weeks: [[DayData?]] = []
        var currentDate = twelveWeeksAgo
        
        while currentDate <= today {
            var week: [DayData?] = []
            
            for _ in 0..<7 {
                let dayEntries = entriesByDate[calendar.startOfDay(for: currentDate)] ?? []
                if currentDate <= today {
                    week.append(DayData(date: currentDate, count: dayEntries.count))
                } else {
                    week.append(nil)
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            weeks.append(week)
        }
        
        return weeks
    }
    
    struct DayData {
        let date: Date
        let count: Int
    }
}

struct CalendarCell: View {
    let count: Int
    let maxCount: Int
    let date: Date
    
    private let cellSize: CGFloat = 15
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cellColor)
            .frame(width: cellSize, height: cellSize)
            .help("\(count) entries on \(date.formatted(date: .abbreviated, time: .omitted))")
    }
    
    private var cellColor: Color {
        if count == 0 {
            return DesignSystem.Colors.backgroundTertiary
        }
        
        let intensity = Double(count) / Double(max(maxCount, 1))
        return DesignSystem.Colors.primary.opacity(0.2 + (intensity * 0.8))
    }
}

// MARK: - Preview

#Preview {
    InsightsView()
        .environment(try! JournalStore())
        .frame(width: 1000, height: 800)
}