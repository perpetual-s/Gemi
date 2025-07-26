import SwiftUI

struct InsightsView: View {
    let entries: [JournalEntry]
    @State private var selectedTimeRange = TimeRange.allTime
    @State private var animateCharts = false
    @StateObject private var analytics = AnalyticsService.shared
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case allTime = "All Time"
    }
    
    var body: some View {
        if entries.isEmpty {
            // Beautiful empty state when no entries
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
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 56))
                        .foregroundColor(Theme.Colors.primaryAccent)
                }
                
                VStack(spacing: Theme.spacing) {
                    Text("No insights yet")
                        .font(Theme.Typography.title)
                        .foregroundColor(.primary)
                    
                    Text("Start journaling to discover patterns and\ntrack your emotional journey over time.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    
                    Button(action: {
                        NotificationCenter.default.post(name: .newEntry, object: nil)
                    }) {
                        Text("Create Your First Entry")
                            .font(Theme.Typography.body.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Theme.Colors.primaryAccent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Theme.spacing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.windowBackground)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    // Enhanced header with time range selector
                    enhancedHeader
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Stats cards with better design
                    statsGrid
                        .padding()
                    
                    // Mood insights section
                    moodInsightsSection
                        .padding(.horizontal)
                        .padding(.bottom)
                    
                    // Writing patterns
                    writingPatternsSection
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .background(Theme.Colors.windowBackground)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    animateCharts = true
                }
            }
        }
    }
    
    private var enhancedHeader: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.Colors.primaryAccent)
                            .symbolRenderingMode(.hierarchical)
                        
                        Text("Journal Insights")
                            .font(Theme.Typography.sectionHeader)
                    }
                    
                    Text("Discover patterns and trends in your writing journey")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue)
                            .tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
                .opacity(0.3)
        }
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.spacing) {
            EnhancedStatCard(
                title: "Total Entries",
                value: "\(filteredEntries.count)",
                icon: "book.closed.fill",
                color: .blue,
                trend: entriesTrend
            )
            
            EnhancedStatCard(
                title: "Words Written",
                value: formatNumber(totalWords),
                icon: "text.alignleft",
                color: .green,
                trend: wordsTrend
            )
            
            EnhancedStatCard(
                title: "Avg. Entry Length",
                value: "\(averageWords) words",
                icon: "chart.bar.fill",
                color: .orange
            )
            
            EnhancedStatCard(
                title: "Writing Streak",
                value: "\(currentStreak) days",
                icon: "flame.fill",
                color: .red,
                subtitle: streakMessage
            )
        }
    }
    
    private var moodInsightsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            // Section header
            HStack {
                Label("Mood Insights", systemImage: "face.smiling")
                    .font(Theme.Typography.headline)
                
                Spacer()
                
                if !moodStats.isEmpty {
                    Text("\(filteredEntries.count) entries")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                }
            }
            
            if moodStats.isEmpty {
                EmptyStateCard(
                    icon: "face.smiling",
                    title: "No mood data yet",
                    subtitle: "Start tracking your mood to see insights"
                )
            } else {
                VStack(spacing: 16) {
                    // Mood distribution with fixed layout
                    VStack(spacing: 12) {
                        ForEach(moodStats.sorted(by: { $0.value > $1.value }), id: \.key) { mood, count in
                            EnhancedMoodDistributionRow(
                                mood: mood,
                                count: count,
                                total: filteredEntries.count,
                                percentage: Double(count) / Double(filteredEntries.count),
                                isAnimated: animateCharts
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .fill(Theme.Colors.cardBackground)
                    )
                    
                    // Mood trend summary
                    if let dominantMood = moodStats.max(by: { $0.value < $1.value })?.key {
                        MoodTrendCard(mood: dominantMood, percentage: Double(moodStats[dominantMood] ?? 0) / Double(filteredEntries.count))
                    }
                }
            }
        }
    }
    
    private var writingPatternsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Label("Writing Patterns", systemImage: "pencil.line")
                .font(Theme.Typography.headline)
            
            VStack(spacing: 16) {
                // Writing habits card
                VStack(alignment: .leading, spacing: 16) {
                    HabitRow(
                        icon: "clock.fill",
                        title: "Most productive time",
                        value: mostProductiveTime
                    )
                    
                    Divider()
                    
                    HabitRow(
                        icon: "timer",
                        title: "Average session",
                        value: averageSessionLength
                    )
                    
                    Divider()
                    
                    HabitRow(
                        icon: "calendar",
                        title: "Most active day",
                        value: mostActiveDay
                    )
                    
                    if !topTags.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.Colors.secondaryText)
                                
                                Text("Popular topics")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                            
                            HStack {
                                ForEach(topTags.prefix(4), id: \.self) { tag in
                                    SimpleTagChip(tag: tag)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .fill(Theme.Colors.cardBackground)
                )
            }
        }
    }
    
    private var filteredEntries: [JournalEntry] {
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
        case .allTime:
            return entries
        }
    }
    
    private var mostProductiveTime: String {
        let calendar = Calendar.current
        var hourCounts: [Int: Int] = [:]
        
        for entry in filteredEntries {
            let hour = calendar.component(.hour, from: entry.createdAt)
            hourCounts[hour, default: 0] += 1
        }
        
        guard let maxHour = hourCounts.max(by: { $0.value < $1.value })?.key else {
            return "No data"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = calendar.date(from: DateComponents(hour: maxHour))!
        return formatter.string(from: date)
    }
    
    private var averageSessionLength: String {
        let duration = analytics.averageSessionDuration(for: selectedTimeRange)
        return AnalyticsService.formatSessionDuration(duration)
    }
    
    private var mostActiveDay: String {
        let calendar = Calendar.current
        var dayCounts: [Int: Int] = [:]
        
        for entry in filteredEntries {
            let weekday = calendar.component(.weekday, from: entry.createdAt)
            dayCounts[weekday, default: 0] += 1
        }
        
        guard let maxDay = dayCounts.max(by: { $0.value < $1.value })?.key else {
            return "No data"
        }
        
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[maxDay - 1]
    }
    
    private var totalWords: Int {
        filteredEntries.reduce(0) { $0 + $1.wordCount }
    }
    
    private var averageWords: Int {
        filteredEntries.isEmpty ? 0 : totalWords / filteredEntries.count
    }
    
    private var entriesTrend: String? {
        guard selectedTimeRange != .allTime else { return nil }
        let trend = analytics.calculateTrend(for: entries, timeRange: selectedTimeRange)
        return AnalyticsService.formatTrend(trend)
    }
    
    private var wordsTrend: String? {
        guard selectedTimeRange != .allTime else { return nil }
        let trend = analytics.calculateWordsTrend(for: entries, timeRange: selectedTimeRange)
        return AnalyticsService.formatTrend(trend)
    }
    
    private var streakMessage: String {
        if currentStreak == 0 {
            return "Start writing today!"
        } else if currentStreak == 1 {
            return "Great start!"
        } else if currentStreak < 7 {
            return "Keep it up!"
        } else if currentStreak < 30 {
            return "Amazing consistency!"
        } else {
            return "Incredible dedication!"
        }
    }
    
    private var currentStreak: Int {
        // Simplified streak calculation
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()
        
        for _ in 0..<365 {
            let hasEntry = entries.contains { entry in
                calendar.isDate(entry.createdAt, inSameDayAs: currentDate)
            }
            
            if hasEntry {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        
        return streak
    }
    
    private var moodStats: [Mood: Int] {
        var stats: [Mood: Int] = [:]
        for entry in filteredEntries {
            if let mood = entry.mood {
                stats[mood, default: 0] += 1
            }
        }
        return stats
    }
    
    private var topTags: [String] {
        var tagCounts: [String: Int] = [:]
        for entry in entries {
            for tag in entry.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        return Array(tagCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key })
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}


struct HabitRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.secondaryText)
                    .frame(width: 20)
                
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            Spacer()
            
            Text(value)
                .font(Theme.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct EnhancedMoodDistributionRow: View {
    let mood: Mood
    let count: Int
    let total: Int
    let percentage: Double
    let isAnimated: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side: Mood info
            HStack(spacing: 10) {
                Text(mood.emoji)
                    .font(.system(size: 24))
                    .frame(width: 30)
                
                Text(mood.rawValue.capitalized)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 80, alignment: .leading)
            }
            
            // Center: Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Theme.Colors.divider.opacity(0.15))
                        .frame(height: 10)
                    
                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    moodColor(for: mood).opacity(0.8),
                                    moodColor(for: mood)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: isAnimated ? geometry.size.width * percentage : 0,
                            height: 10
                        )
                        .animation(
                            .spring(response: 0.8, dampingFraction: 0.85)
                            .delay(Double(moodOrder(mood)) * 0.05),
                            value: isAnimated
                        )
                }
            }
            .frame(height: 10)
            
            // Right side: Count and percentage
            HStack(spacing: 6) {
                Text("\(count)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 30, alignment: .trailing)
                
                Text("\(Int(percentage * 100))%")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.secondaryText)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .frame(height: 30)
    }
    
    private func moodOrder(_ mood: Mood) -> Int {
        // Define order for animation delay
        let order = [Mood.happy, .excited, .peaceful, .grateful, .neutral, .anxious, .sad, .frustrated, .angry]
        return order.firstIndex(of: mood) ?? 0
    }
    
    private func moodColor(for mood: Mood) -> Color {
        switch mood {
        case .happy, .excited:
            return .green
        case .peaceful, .grateful:
            return .blue
        case .neutral:
            return .gray
        case .anxious:
            return .orange
        case .frustrated:
            return .red
        case .sad:
            return .purple
        case .accomplished:
            return .indigo
        case .angry:
            return .red
        }
    }
}

// MARK: - Enhanced Stat Card

struct EnhancedStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var trend: String? = nil
    var subtitle: String? = nil
    
    @State private var isAnimated = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .symbolRenderingMode(.hierarchical)
                
                Spacer()
                
                if let trend = trend {
                    Label(trend, systemImage: trend.starts(with: "+") ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(trend.starts(with: "+") ? .green : .red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .scaleEffect(isAnimated ? 1 : 0.8)
                    .opacity(isAnimated ? 1 : 0)
                
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                // Subtitle area with consistent height
                Text(subtitle ?? " ")
                    .font(.system(size: 11))
                    .foregroundColor(subtitle != nil ? color : .clear)
                    .frame(height: 14)  // Fixed height for subtitle area
                    .padding(.top, 2)
            }
        }
        .padding()
        .frame(minHeight: 140, maxHeight: 140)  // Fixed height for all cards
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                isAnimated = true
            }
        }
    }
}

// MARK: - Mood Trend Card

struct MoodTrendCard: View {
    let mood: Mood
    let percentage: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your dominant mood")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                HStack(spacing: 12) {
                    Text(mood.emoji)
                        .font(.system(size: 32))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mood.rawValue.capitalized)
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("\(Int(percentage * 100))% of entries")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "face.smiling.inverse")
                .font(.system(size: 40))
                .foregroundColor(moodColor(for: mood).opacity(0.2))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(moodColor(for: mood).opacity(0.1))
        )
    }
    
    private func moodColor(for mood: Mood) -> Color {
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

// MARK: - Empty State Card

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.tertiaryText)
            
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.secondaryText)
            
            Text(subtitle)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.Colors.cardBackground.opacity(0.5))
        )
    }
}

// Simple tag chip component for insights view
struct SimpleTagChip: View {
    let tag: String
    
    var body: some View {
        Text("#\(tag)")
            .font(.system(size: 13))
            .foregroundColor(Theme.Colors.primaryAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.Colors.primaryAccent.opacity(0.1))
            )
    }
}


