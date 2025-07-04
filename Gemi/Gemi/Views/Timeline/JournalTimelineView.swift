//
//  TimelineView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct JournalTimelineView: View {
    @Environment(JournalStore.self) private var journalStore
    @Environment(NavigationModel.self) private var navigationModel
    @State private var filteredEntries: [JournalEntry] = []
    
    // View options
    @State private var groupingMode: GroupingMode = .day
    @State private var viewMode: ViewMode = .list
    @State private var selectedEntryIDs: Set<String> = []
    @State private var isMultiSelectMode = false
    
    // Filters
    @State private var searchQuery = ""
    @State private var selectedMoods: Set<MoodIndicator.Mood> = []
    @State private var selectedTags: Set<String> = []
    @State private var dateRange: ClosedRange<Date>?
    @State private var showFilters = false
    
    // Calendar
    @State private var showCalendar = false
    @State private var selectedDate: Date?
    
    enum GroupingMode: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        
        var icon: String {
            switch self {
            case .day: return "calendar.day.timeline.left"
            case .week: return "calendar"
            case .month: return "calendar.badge.clock"
            case .year: return "calendar.circle"
            }
        }
    }
    
    enum ViewMode: String, CaseIterable {
        case list = "List"
        case grid = "Grid"
        case timeline = "Timeline"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            case .timeline: return "timeline.selection"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            timelineHeader
            
            Divider()
            
            // Main content
            if viewMode == .timeline {
                visualTimelineView
            } else {
                standardTimelineView
            }
        }
        .background(ModernDesignSystem.Colors.backgroundSecondary)
        .task {
            await loadEntries()
        }
    }
    
    @ViewBuilder
    private var timelineHeader: some View {
        VStack(spacing: 0) {
            // Primary toolbar
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                // Title and stats
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Timeline")
                        .font(ModernDesignSystem.Typography.title2)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack(spacing: 4) {
                        Text("\(filteredEntries.count) entries")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        if journalStore.hasMore {
                            Text("• More available")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                        }
                    }
                }
                
                Spacer()
                
                // View mode picker
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                // Grouping picker
                Picker("Group By", selection: $groupingMode) {
                    ForEach(GroupingMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                
                // Calendar button
                Button {
                    showCalendar.toggle()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showCalendar) {
                    CalendarWidget(
                        selectedDate: $selectedDate,
                        entriesDict: groupEntriesByDate()
                    )
                }
                
                // Filter button
                Button {
                    showFilters.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16))
                        .foregroundColor(hasActiveFilters ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showFilters) {
                    FilterPanel(
                        selectedMoods: $selectedMoods,
                        selectedTags: $selectedTags,
                        dateRange: $dateRange,
                        availableTags: extractAllTags()
                    )
                }
                
                // Multi-select toggle
                Toggle(isOn: $isMultiSelectMode) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 16))
                }
                .toggleStyle(.button)
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.vertical, ModernDesignSystem.Spacing.md)
            
            // Search bar
            if !searchQuery.isEmpty || isMultiSelectMode {
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: ModernDesignSystem.Spacing.md) {
                        // Search field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            
                            TextField("Search entries...", text: $searchQuery)
                                .textFieldStyle(.plain)
                                .font(ModernDesignSystem.Typography.body)
                            
                            if !searchQuery.isEmpty {
                                Button {
                                    searchQuery = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                                .fill(ModernDesignSystem.Colors.backgroundTertiary)
                        )
                        
                        // Bulk actions
                        if isMultiSelectMode && !selectedEntryIDs.isEmpty {
                            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                                Text("\(selectedEntryIDs.count) selected")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                
                                Button("Export") {
                                    exportSelectedEntries()
                                }
                                .buttonStyle(.plain)
                                
                                Button("Delete", role: .destructive) {
                                    deleteSelectedEntries()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    @ViewBuilder
    private var standardTimelineView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(groupedEntries(), id: \.key) { group in
                        Section {
                            if viewMode == .list {
                                listContent(for: group.value)
                            } else {
                                gridContent(for: group.value)
                            }
                        } header: {
                            sectionHeader(for: group.key)
                        }
                    }
                    
                    // Load more indicator
                    if journalStore.hasMore && !journalStore.entries.isEmpty {
                        loadMoreIndicator
                            .onAppear {
                                Task {
                                    await journalStore.loadMoreEntries()
                                    applyFilters()
                                }
                            }
                    }
                }
                .padding(.vertical, ModernDesignSystem.Spacing.md)
            }
            .onChange(of: selectedDate) { _, newDate in
                if let date = newDate {
                    scrollToDate(date, using: proxy)
                }
            }
        }
    }
    
    @ViewBuilder
    private var visualTimelineView: some View {
        ScrollView {
            ZStack(alignment: .leading) {
                // Timeline line
                Rectangle()
                    .fill(ModernDesignSystem.Colors.divider)
                    .frame(width: 2)
                    .padding(.leading, 40)
                
                // Entries
                LazyVStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xl) {
                    ForEach(filteredEntries) { entry in
                        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.md) {
                            // Timeline node
                            VStack {
                                Circle()
                                    .fill(moodColor(for: entry))
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(ModernDesignSystem.Colors.backgroundSecondary, lineWidth: 3)
                                    )
                                
                                Spacer()
                            }
                            .frame(width: 12)
                            .padding(.leading, 35)
                            
                            // Entry card
                            TimelineEntryCard(
                                entry: entry,
                                isSelected: selectedEntryIDs.contains(entry.id.uuidString),
                                isHovered: false,
                                onTap: {
                                    handleEntryTap(entry)
                                },
                                onEdit: {
                                    editEntry(entry)
                                },
                                onDelete: {
                                    deleteEntry(entry)
                                },
                                onShare: {
                                    shareEntry(entry)
                                }
                            )
                            .frame(maxWidth: 600)
                        }
                    }
                    
                    if journalStore.hasMore && !journalStore.entries.isEmpty {
                        loadMoreIndicator
                            .padding(.leading, 60)
                            .onAppear {
                                Task {
                                    await journalStore.loadMoreEntries()
                                    applyFilters()
                                }
                            }
                    }
                }
                .padding(.vertical, ModernDesignSystem.Spacing.lg)
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        }
    }
    
    @ViewBuilder
    private func listContent(for entries: [JournalEntry]) -> some View {
        ForEach(entries) { entry in
            TimelineEntryCard(
                entry: entry,
                isSelected: selectedEntryIDs.contains(entry.id.uuidString),
                isHovered: false,
                onTap: {
                    handleEntryTap(entry)
                },
                onEdit: {
                    editEntry(entry)
                },
                onDelete: {
                    deleteEntry(entry)
                },
                onShare: {
                    shareEntry(entry)
                }
            )
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.vertical, ModernDesignSystem.Spacing.xs)
            .id(entry.id)
        }
    }
    
    @ViewBuilder
    private func gridContent(for entries: [JournalEntry]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 250, maximum: 350), spacing: ModernDesignSystem.Spacing.md)
            ],
            spacing: ModernDesignSystem.Spacing.md
        ) {
            ForEach(entries) { entry in
                CompactTimelineCard(
                    entry: entry,
                    isSelected: selectedEntryIDs.contains(entry.id.uuidString),
                    onTap: {
                        handleEntryTap(entry)
                    }
                )
                .id(entry.id)
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
    }
    
    @ViewBuilder
    private func sectionHeader(for date: Date) -> some View {
        HStack {
            Text(formatGroupDate(date))
                .font(ModernDesignSystem.Typography.headline)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Spacer()
            
            // Entry count for this group
            if let count = groupedEntries().first(where: { $0.key == date })?.value.count {
                Text("\(count) entries")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .background(
            Rectangle()
                .fill(ModernDesignSystem.Colors.backgroundSecondary.opacity(0.95))
        )
    }
    
    @ViewBuilder
    private var loadMoreIndicator: some View {
        HStack {
            Spacer()
            
            if journalStore.isLoadingMore {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button("Load More") {
                    Task {
                        await journalStore.loadMoreEntries()
                        applyFilters()
                    }
                }
                .font(ModernDesignSystem.Typography.callout)
                .foregroundColor(ModernDesignSystem.Colors.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, ModernDesignSystem.Spacing.lg)
    }
    
    // MARK: - Data Management
    
    private func loadEntries() async {
        // Load initial entries
        await journalStore.loadEntries()
        
        // Apply filters
        applyFilters()
    }
    
    private func applyFilters() {
        filteredEntries = journalStore.entries
        
        // Search filter
        if !searchQuery.isEmpty {
            filteredEntries = filteredEntries.filter { entry in
                entry.title.localizedCaseInsensitiveContains(searchQuery) ||
                entry.content.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Mood filter
        if !selectedMoods.isEmpty {
            filteredEntries = filteredEntries.filter { entry in
                if let moodString = entry.mood,
                   let mood = MoodIndicator.Mood(rawValue: moodString) {
                    return selectedMoods.contains(mood)
                }
                return false
            }
        }
        
        // Tag filter
        if !selectedTags.isEmpty {
            filteredEntries = filteredEntries.filter { entry in
                let entryTags = extractTags(from: entry.content)
                return !selectedTags.isDisjoint(with: Set(entryTags))
            }
        }
        
        // Date range filter
        if let range = dateRange {
            filteredEntries = filteredEntries.filter { entry in
                range.contains(entry.date)
            }
        }
    }
    
    // MARK: - Grouping
    
    private func groupedEntries() -> [(key: Date, value: [JournalEntry])] {
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            groupingKey(for: entry.date)
        }
        
        return grouped.sorted { $0.key > $1.key }
    }
    
    private func groupingKey(for date: Date) -> Date {
        let calendar = Calendar.current
        
        switch groupingMode {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start ?? date
        case .year:
            return calendar.dateInterval(of: .year, for: date)?.start ?? date
        }
    }
    
    private func formatGroupDate(_ date: Date) -> String {
        switch groupingMode {
        case .day:
            if Calendar.current.isDateInToday(date) {
                return "Today"
            } else if Calendar.current.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
            }
        case .week:
            let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: date) ?? date
            return "\(date.formatted(.dateTime.month(.abbreviated).day())) - \(endOfWeek.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return date.formatted(.dateTime.month(.wide).year())
        case .year:
            return date.formatted(.dateTime.year())
        }
    }
    
    // MARK: - Helpers
    
    private func groupEntriesByDate() -> [Date: Int] {
        Dictionary(grouping: journalStore.entries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }.mapValues { $0.count }
    }
    
    private func extractTags(from content: String) -> [String] {
        let pattern = "#[a-zA-Z0-9_]+"
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: content, range: NSRange(content.startIndex..., in: content)) ?? []
        
        return matches.compactMap { match in
            if let range = Range(match.range, in: content) {
                return String(content[range])
            }
            return nil
        }
    }
    
    private func extractAllTags() -> Set<String> {
        Set(journalStore.entries.flatMap { extractTags(from: $0.content) })
    }
    
    private func moodColor(for entry: JournalEntry) -> Color {
        if let moodString = entry.mood,
           let mood = MoodIndicator.Mood(rawValue: moodString) {
            return mood.color
        }
        return ModernDesignSystem.Colors.textTertiary
    }
    
    private var hasActiveFilters: Bool {
        !searchQuery.isEmpty || !selectedMoods.isEmpty || !selectedTags.isEmpty || dateRange != nil
    }
    
    // MARK: - Actions
    
    private func handleEntryTap(_ entry: JournalEntry) {
        if isMultiSelectMode {
            if selectedEntryIDs.contains(entry.id.uuidString) {
                selectedEntryIDs.remove(entry.id.uuidString)
            } else {
                selectedEntryIDs.insert(entry.id.uuidString)
            }
        } else {
            editEntry(entry)
        }
    }
    
    private func editEntry(_ entry: JournalEntry) {
        navigationModel.openEntry(entry)
    }
    
    private func deleteEntry(_ entry: JournalEntry) {
        Task {
            _ = try? await journalStore.deleteEntry(entry)
            await loadEntries()
        }
    }
    
    private func shareEntry(_ entry: JournalEntry) {
        // TODO: Implement sharing
    }
    
    private func exportSelectedEntries() {
        // TODO: Implement export
    }
    
    private func deleteSelectedEntries() {
        // TODO: Implement bulk delete
    }
    
    private func scrollToDate(_ date: Date, using proxy: ScrollViewProxy) {
        // Find the first entry on or after the selected date
        if let entry = filteredEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            withAnimation {
                proxy.scrollTo(entry.id, anchor: .top)
            }
        }
    }
}