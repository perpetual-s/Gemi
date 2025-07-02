//
//  CalendarWidget.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct CalendarWidget: View {
    @Binding var selectedDate: Date?
    let entriesDict: [Date: Int]
    
    @State private var displayedMonth = Date()
    @State private var hoveredDate: Date?
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            calendarHeader
            
            Divider()
            
            // Days of week
            daysOfWeekHeader
            
            // Calendar grid
            calendarGrid
                .padding(ModernDesignSystem.Spacing.md)
        }
        .frame(width: 350)
        .background(ModernDesignSystem.Colors.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD))
        .shadow(radius: 20)
    }
    
    @ViewBuilder
    private var calendarHeader: some View {
        HStack {
            Button {
                withAnimation {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Text(dateFormatter.string(from: displayedMonth))
                .font(ModernDesignSystem.Typography.headline)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Button {
                withAnimation {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            Divider()
                .frame(height: 20)
                .padding(.horizontal, ModernDesignSystem.Spacing.xs)
            
            Button {
                withAnimation {
                    displayedMonth = Date()
                    selectedDate = calendar.startOfDay(for: Date())
                }
            } label: {
                Text("Today")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(ModernDesignSystem.Spacing.md)
    }
    
    @ViewBuilder
    private var daysOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                Text(day)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .padding(.vertical, ModernDesignSystem.Spacing.xs)
    }
    
    @ViewBuilder
    private var calendarGrid: some View {
        let days = generateDaysInMonth()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .frame(height: 40)
                }
            }
        }
    }
    
    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let dayStart = calendar.startOfDay(for: date)
        let entryCount = entriesDict[dayStart] ?? 0
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let isHovered = hoveredDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        
        Button {
            selectedDate = dayStart
        } label: {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected ? ModernDesignSystem.Colors.primary :
                        isToday ? ModernDesignSystem.Colors.primary.opacity(0.1) :
                        isHovered ? ModernDesignSystem.Colors.backgroundTertiary :
                        Color.clear
                    )
                
                VStack(spacing: 2) {
                    // Day number
                    Text("\(calendar.component(.day, from: date))")
                        .font(ModernDesignSystem.Typography.callout)
                        .foregroundColor(
                            isSelected ? .white :
                            !isCurrentMonth ? ModernDesignSystem.Colors.textTertiary :
                            isToday ? ModernDesignSystem.Colors.primary :
                            ModernDesignSystem.Colors.textPrimary
                        )
                    
                    // Entry indicator
                    if entryCount > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<min(entryCount, 3), id: \.self) { _ in
                                Circle()
                                    .fill(
                                        isSelected ? Color.white.opacity(0.8) :
                                        ModernDesignSystem.Colors.primary
                                    )
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                }
            }
            .frame(height: 40)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            hoveredDate = hovering ? date : nil
        }
    }
    
    private func generateDaysInMonth() -> [Date?] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Fill remaining days to complete the grid
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
}