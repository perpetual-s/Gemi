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
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
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
            
            // Mood chart placeholder
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                .fill(DesignSystem.Colors.backgroundSecondary)
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Text("Mood tracking coming soon")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                )
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
                    description: "Personal growth, Work, Relationships",
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
            } else if let insights = insights {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    ForEach(insights.patterns, id: \.self) { pattern in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.small) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 14))
                                .foregroundStyle(DesignSystem.Colors.primary)
                                .padding(.top, 2)
                            
                            Text(pattern)
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
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
        
        // Simulate AI analysis
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        insights = JournalInsights(
            patterns: [
                "You tend to write more on weekends, especially Sunday evenings",
                "Your mood improves after journaling about gratitude",
                "You've been focusing on personal growth themes this month",
                "Writing in the morning correlates with more positive entries"
            ]
        )
        
        isAnalyzing = false
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

// MARK: - Preview

#Preview {
    InsightsView()
        .environment(try! JournalStore())
        .frame(width: 1000, height: 800)
}