import SwiftUI
import Charts

/// Quick insights card for timeline view showing journal patterns and analysis
struct TimelineInsightsCard: View {
    let entries: [JournalEntry]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = InsightTab.overview
    @State private var isAnalyzing = true
    @State private var insights: JournalInsights?
    
    enum InsightTab: String, CaseIterable {
        case overview = "Overview"
        case moods = "Mood Patterns"
        case themes = "Key Themes"
        case growth = "Personal Growth"
        
        var icon: String {
            switch self {
            case .overview: return "chart.line.uptrend.xyaxis"
            case .moods: return "face.smiling"
            case .themes: return "tag"
            case .growth: return "arrow.up.forward"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Tab selector
            Picker("Insights", selection: $selectedTab) {
                ForEach(InsightTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            if isAnalyzing {
                ProgressView("Analyzing your journal entries...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let insights = insights {
                ScrollView {
                    insightContent(insights: insights)
                        .padding()
                }
            }
        }
        .frame(width: 800, height: 600)
        .background(Theme.Colors.windowBackground)
        .onAppear {
            analyzeEntries()
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Insights")
                    .font(Theme.Typography.largeTitle)
                
                Text("Patterns and analysis from your \(entries.count) journal entries")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func insightContent(insights: JournalInsights) -> some View {
        switch selectedTab {
        case .overview:
            OverviewInsights(insights: insights)
        case .moods:
            MoodInsights(insights: insights)
        case .themes:
            ThemeInsights(insights: insights)
        case .growth:
            GrowthInsights(insights: insights)
        }
    }
    
    private func analyzeEntries() {
        Task {
            // Simulate AI analysis
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            await MainActor.run {
                self.insights = generateInsights()
                self.isAnalyzing = false
            }
        }
    }
    
    private func generateInsights() -> JournalInsights {
        // Analyze entries
        let moods = entries.compactMap { $0.mood }
        let moodCounts = Dictionary(grouping: moods, by: { $0 }).mapValues { $0.count }
        
        let allTags = entries.flatMap { $0.tags }
        let tagCounts = Dictionary(grouping: allTags, by: { $0 }).mapValues { $0.count }
        let topTags = tagCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        
        let totalWords = entries.reduce(0) { $0 + $1.wordCount }
        let avgWordsPerEntry = entries.isEmpty ? 0 : totalWords / entries.count
        
        // Generate writing patterns
        let calendar = Calendar.current
        let entriesByHour = Dictionary(grouping: entries) { entry in
            calendar.component(.hour, from: entry.createdAt)
        }
        let mostActiveHour = entriesByHour.max { $0.value.count < $1.value.count }?.key ?? 0
        
        return JournalInsights(
            totalEntries: entries.count,
            totalWords: totalWords,
            avgWordsPerEntry: avgWordsPerEntry,
            moodDistribution: moodCounts,
            topThemes: topTags,
            mostActiveHour: mostActiveHour,
            writingStreak: calculateWritingStreak(),
            growthAreas: identifyGrowthAreas(),
            recommendations: generateRecommendations()
        )
    }
    
    private func calculateWritingStreak() -> Int {
        guard !entries.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let sortedDates = entries.map { calendar.startOfDay(for: $0.createdAt) }.sorted(by: >)
        
        var streak = 1
        var currentDate = sortedDates[0]
        
        for date in sortedDates.dropFirst() {
            let daysBetween = calendar.dateComponents([.day], from: date, to: currentDate).day ?? 0
            if daysBetween == 1 {
                streak += 1
                currentDate = date
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func identifyGrowthAreas() -> [String] {
        // Simplified growth area identification
        var areas: [String] = []
        
        let positiveEntries = entries.filter { entry in
            guard let mood = entry.mood else { return false }
            return mood == .happy || mood == .excited || mood == .grateful
        }
        
        if Double(positiveEntries.count) / Double(entries.count) > 0.6 {
            areas.append("Maintaining positive outlook")
        }
        
        if entries.filter({ $0.wordCount > 300 }).count > entries.count / 2 {
            areas.append("Consistent self-reflection")
        }
        
        let uniqueTags = Set(entries.flatMap { $0.tags })
        if uniqueTags.count > 10 {
            areas.append("Exploring diverse topics")
        }
        
        return areas
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        // Based on mood patterns
        let moods = entries.compactMap { $0.mood }
        let stressedCount = moods.filter { $0 == .anxious }.count
        if Double(stressedCount) / Double(moods.count) > 0.3 {
            recommendations.append("Consider exploring stress management techniques in your writing")
        }
        
        // Based on writing frequency
        if entries.count < 10 {
            recommendations.append("Try to journal more regularly to build a consistent habit")
        }
        
        // Based on entry length
        let avgWords = entries.isEmpty ? 0 : entries.reduce(0) { $0 + $1.wordCount } / entries.count
        if avgWords < 100 {
            recommendations.append("Try writing longer entries to explore your thoughts more deeply")
        }
        
        return recommendations
    }
}

// MARK: - Insight Views

struct OverviewInsights: View {
    let insights: JournalInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.largeSpacing) {
            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.spacing) {
                AIStatCard(
                    title: "Total Entries",
                    value: "\(insights.totalEntries)",
                    icon: "book.fill",
                    color: .blue
                )
                
                AIStatCard(
                    title: "Total Words",
                    value: "\(insights.totalWords)",
                    icon: "text.alignleft",
                    color: .green
                )
                
                AIStatCard(
                    title: "Writing Streak",
                    value: "\(insights.writingStreak) days",
                    icon: "flame.fill",
                    color: .orange
                )
                
                AIStatCard(
                    title: "Avg Words/Entry",
                    value: "\(insights.avgWordsPerEntry)",
                    icon: "chart.bar.fill",
                    color: .purple
                )
            }
            
            // Recommendations
            if !insights.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    Text("AI Recommendations")
                        .font(Theme.Typography.headline)
                    
                    ForEach(insights.recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: Theme.spacing) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            
                            Text(recommendation)
                                .font(Theme.Typography.body)
                        }
                        .padding()
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.smallCornerRadius)
                    }
                }
            }
            
            // Growth areas
            if !insights.growthAreas.isEmpty {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    Text("Areas of Growth")
                        .font(Theme.Typography.headline)
                    
                    HStack(spacing: Theme.spacing) {
                        ForEach(insights.growthAreas, id: \.self) { area in
                            Label(area, systemImage: "checkmark.circle.fill")
                                .font(Theme.Typography.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, Theme.spacing)
                                .padding(.vertical, Theme.smallSpacing)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(Theme.cornerRadius)
                        }
                    }
                }
            }
        }
    }
}

struct MoodInsights: View {
    let insights: JournalInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.largeSpacing) {
            Text("Mood Distribution")
                .font(Theme.Typography.headline)
            
            // Mood chart
            if !insights.moodDistribution.isEmpty {
                Chart(insights.moodDistribution.sorted(by: { $0.value > $1.value }), id: \.key) { mood, count in
                    BarMark(
                        x: .value("Count", count),
                        y: .value("Mood", mood.rawValue)
                    )
                    .foregroundStyle(by: .value("Mood", mood.rawValue))
                    .annotation(position: .trailing) {
                        Text("\(mood.emoji)")
                            .font(.title3)
                    }
                }
                .frame(height: 300)
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            }
            
            // Mood trends
            VStack(alignment: .leading, spacing: Theme.spacing) {
                Text("Mood Insights")
                    .font(Theme.Typography.headline)
                
                if let dominantMood = insights.moodDistribution.max(by: { $0.value < $1.value })?.key {
                    InsightCard(
                        icon: "face.smiling",
                        title: "Dominant Mood",
                        description: "You've been feeling \(dominantMood.rawValue.lowercased()) most often. \(dominantMood.emoji)"
                    )
                }
                
                InsightCard(
                    icon: "clock",
                    title: "Most Active Hour",
                    description: "You tend to journal most at \(formatHour(insights.mostActiveHour))"
                )
            }
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
}

struct ThemeInsights: View {
    let insights: JournalInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.largeSpacing) {
            Text("Your Top Themes")
                .font(Theme.Typography.headline)
            
            if insights.topThemes.isEmpty {
                Text("Start adding tags to your entries to see theme insights")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            } else {
                ForEach(insights.topThemes, id: \.self) { theme in
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(Theme.Colors.primaryAccent)
                        
                        Text(theme)
                            .font(Theme.Typography.body)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.smallCornerRadius)
                }
            }
        }
    }
}

struct GrowthInsights: View {
    let insights: JournalInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.largeSpacing) {
            Text("Your Growth Journey")
                .font(Theme.Typography.headline)
            
            // Writing consistency
            GrowthCard(
                title: "Writing Consistency",
                progress: min(Double(insights.writingStreak) / 30.0, 1.0),
                description: "\(insights.writingStreak) day streak - Keep it up!"
            )
            
            // Expression depth
            let avgWords = Double(insights.avgWordsPerEntry)
            let depthProgress = min(avgWords / 300.0, 1.0)
            GrowthCard(
                title: "Expression Depth",
                progress: depthProgress,
                description: "Average \(insights.avgWordsPerEntry) words per entry"
            )
            
            // Emotional awareness
            let moodVariety = Double(insights.moodDistribution.count) / 9.0
            GrowthCard(
                title: "Emotional Awareness",
                progress: moodVariety,
                description: "Tracking \(insights.moodDistribution.count) different moods"
            )
        }
    }
}

// MARK: - Supporting Components

struct AIStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(Theme.Typography.largeTitle)
                .fontWeight(.semibold)
            
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(Theme.cornerRadius)
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacing) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Theme.Colors.primaryAccent)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.headline)
                
                Text(description)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            Spacer()
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.smallCornerRadius)
    }
}

struct GrowthCard: View {
    let title: String
    let progress: Double
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(title)
                .font(Theme.Typography.headline)
            
            ProgressView(value: progress)
                .tint(Theme.Colors.primaryAccent)
            
            Text(description)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.smallCornerRadius)
    }
}

// MARK: - Data Model

struct JournalInsights {
    let totalEntries: Int
    let totalWords: Int
    let avgWordsPerEntry: Int
    let moodDistribution: [Mood: Int]
    let topThemes: [String]
    let mostActiveHour: Int
    let writingStreak: Int
    let growthAreas: [String]
    let recommendations: [String]
}