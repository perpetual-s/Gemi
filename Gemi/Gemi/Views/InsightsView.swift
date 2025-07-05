import SwiftUI

struct InsightsView: View {
    let entries: [JournalEntry]
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.largeSpacing) {
                header
                
                statsGrid
                
                moodChart
                
                writingHabits
            }
            .padding()
        }
        .background(Theme.Colors.windowBackground)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Journal Insights")
                .font(Theme.Typography.largeTitle)
            
            Text("Discover patterns and trends in your writing")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.spacing) {
            StatCard(
                title: "Total Entries",
                value: "\(entries.count)",
                icon: "book.closed",
                color: .blue
            )
            
            StatCard(
                title: "Words Written",
                value: formatNumber(totalWords),
                icon: "text.alignleft",
                color: .green
            )
            
            StatCard(
                title: "Avg. Entry Length",
                value: "\(averageWords) words",
                icon: "chart.bar",
                color: .orange
            )
            
            StatCard(
                title: "Writing Streak",
                value: "\(currentStreak) days",
                icon: "flame",
                color: .red
            )
        }
    }
    
    private var moodChart: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Mood Distribution")
                .font(Theme.Typography.headline)
            
            VStack(spacing: 8) {
                ForEach(moodStats.sorted(by: { $0.value > $1.value }), id: \.key) { mood, count in
                    HStack {
                        Text("\(mood.emoji) \(mood.rawValue.capitalized)")
                            .font(Theme.Typography.body)
                            .frame(width: 100, alignment: .leading)
                        
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Theme.Colors.primaryAccent)
                                .frame(width: geometry.size.width * (Double(count) / Double(entries.count)))
                                .cornerRadius(4)
                        }
                        .frame(height: 20)
                        
                        Text("\(count)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
            .padding()
            .cardStyle()
        }
    }
    
    private var writingHabits: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Writing Habits")
                .font(Theme.Typography.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HabitRow(
                    title: "Most productive time",
                    value: "Evening (6-9 PM)"
                )
                
                HabitRow(
                    title: "Average session",
                    value: "23 minutes"
                )
                
                HabitRow(
                    title: "Favorite day",
                    value: "Sunday"
                )
                
                HabitRow(
                    title: "Common tags",
                    value: topTags.joined(separator: ", ")
                )
            }
            .padding()
            .cardStyle()
        }
    }
    
    private var totalWords: Int {
        entries.reduce(0) { $0 + $1.wordCount }
    }
    
    private var averageWords: Int {
        entries.isEmpty ? 0 : totalWords / entries.count
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
        for entry in entries {
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

struct StatCard: View {
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
            
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding()
        .cardStyle()
    }
}

struct HabitRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(Theme.Typography.body)
                .fontWeight(.medium)
        }
    }
}