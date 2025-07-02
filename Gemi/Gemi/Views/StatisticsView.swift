//
//  StatisticsView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(JournalStore.self) private var journalStore
    
    @State private var selectedTimeRange = StatsTimeRange.week
    @State private var dailyStats: [DailyStat] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // Time range selector
                    timeRangeSelector
                    
                    // Overview cards
                    overviewCards
                    
                    // Writing frequency chart
                    writingFrequencyChart
                    
                    // Word count chart
                    wordCountChart
                    
                    Spacer(minLength: ModernDesignSystem.Spacing.xl)
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
        }
        .frame(width: 700, height: 800)
        .background(ModernDesignSystem.Colors.backgroundPrimary)
        .onAppear {
            calculateStats()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            calculateStats()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Writing Statistics")
                .font(ModernDesignSystem.Typography.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(ModernDesignSystem.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(ModernDesignSystem.Spacing.md)
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(StatsTimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 300)
    }
    
    // MARK: - Overview Cards
    
    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ModernDesignSystem.Spacing.md) {
            OverviewCard(
                title: "Total Entries",
                value: "\(journalStore.entryCount)",
                icon: "book.fill",
                color: ModernDesignSystem.Colors.primary
            )
            
            OverviewCard(
                title: "Current Streak",
                value: "\(journalStore.currentStreak) days",
                icon: "flame.fill",
                color: .orange
            )
            
            OverviewCard(
                title: "Total Words",
                value: formatNumber(totalWordCount),
                icon: "text.alignleft",
                color: .green
            )
            
            OverviewCard(
                title: "Avg. Entry Length",
                value: "\(averageEntryLength) words",
                icon: "chart.bar.fill",
                color: .purple
            )
        }
    }
    
    // MARK: - Writing Frequency Chart
    
    @ViewBuilder
    private var writingFrequencyChart: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Writing Frequency")
                .font(ModernDesignSystem.Typography.headline)
                .foregroundStyle(ModernDesignSystem.Colors.textPrimary)
            
            Chart(dailyStats) { stat in
                BarMark(
                    x: .value("Date", stat.date),
                    y: .value("Entries", stat.entryCount)
                )
                .foregroundStyle(ModernDesignSystem.Colors.primary)
            }
            .frame(height: 200)
            .padding(.top, ModernDesignSystem.Spacing.sm)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                .fill(ModernDesignSystem.Colors.backgroundSecondary)
        )
    }
    
    // MARK: - Word Count Chart
    
    @ViewBuilder
    private var wordCountChart: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Word Count Trend")
                .font(ModernDesignSystem.Typography.headline)
                .foregroundStyle(ModernDesignSystem.Colors.textPrimary)
            
            Chart(dailyStats) { stat in
                LineMark(
                    x: .value("Date", stat.date),
                    y: .value("Words", stat.totalWords)
                )
                .foregroundStyle(ModernDesignSystem.Colors.primary)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", stat.date),
                    y: .value("Words", stat.totalWords)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            ModernDesignSystem.Colors.primary.opacity(0.3),
                            ModernDesignSystem.Colors.primary.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 200)
            .padding(.top, ModernDesignSystem.Spacing.sm)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                .fill(ModernDesignSystem.Colors.backgroundSecondary)
        )
    }
    
    // MARK: - Computed Properties
    
    private var totalWordCount: Int {
        journalStore.entries.reduce(0) { total, entry in
            total + entry.content.split(separator: " ").count
        }
    }
    
    private var averageEntryLength: Int {
        guard !journalStore.entries.isEmpty else { return 0 }
        return totalWordCount / journalStore.entries.count
    }
    
    // MARK: - Helper Methods
    
    private func calculateStats() {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate: Date
        
        switch selectedTimeRange {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        }
        
        // Group entries by date
        var statsByDate: [Date: DailyStat] = [:]
        
        // Initialize all dates in range
        var currentDate = startDate
        while currentDate <= endDate {
            let normalizedDate = calendar.startOfDay(for: currentDate)
            statsByDate[normalizedDate] = DailyStat(date: normalizedDate, entryCount: 0, totalWords: 0)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        // Count entries and words
        for entry in journalStore.entries {
            let entryDate = calendar.startOfDay(for: entry.date)
            if entryDate >= startDate && entryDate <= endDate {
                statsByDate[entryDate]?.entryCount += 1
                statsByDate[entryDate]?.totalWords += entry.content.split(separator: " ").count
            }
        }
        
        // Convert to array and sort
        dailyStats = statsByDate.values.sorted { $0.date < $1.date }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Supporting Types

enum StatsTimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    var id: String { rawValue }
}

struct DailyStat: Identifiable {
    let id = UUID()
    let date: Date
    var entryCount: Int
    var totalWords: Int
}

struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            Text(value)
                .font(ModernDesignSystem.Typography.title2)
                .fontWeight(.semibold)
                .foregroundStyle(ModernDesignSystem.Colors.textPrimary)
            
            Text(title)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundStyle(ModernDesignSystem.Colors.textSecondary)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                .fill(ModernDesignSystem.Colors.backgroundSecondary)
        )
    }
}

// MARK: - Preview

#Preview {
    StatisticsView()
        .environment(try! JournalStore())
}