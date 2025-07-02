//
//  MemoryPanelView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import SwiftUI
import os.log

/// A transparent view into Gemi's memory system, giving users full control
struct MemoryPanelView: View {
    @StateObject private var viewModel = MemoryPanelViewModel()
    @State private var selectedTab: MemoryTab = .all
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSheet = false
    @State private var selectedMemories = Set<UUID>()
    @State private var isInSelectionMode = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                memoryTabSelector
                
                // Search bar
                searchBar
                
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .all:
                        allMemoriesView
                    case .insights:
                        memoryInsightsView
                    case .settings:
                        memorySettingsView
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("Gemi's Memory")
            .toolbar {
                toolbarContent
            }
            .task {
                await viewModel.loadMemories()
            }
            .sheet(isPresented: $showingExportSheet) {
                MemoryExportView(memories: viewModel.filteredMemories)
            }
            .confirmationDialog(
                "Clear All Memories",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Memories", role: .destructive) {
                    Task {
                        await viewModel.clearAllMemories()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(viewModel.totalMemoryCount) memories. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var memoryTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(MemoryTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.title)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? DesignSystem.Colors.primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab ?
                        DesignSystem.Colors.primary.opacity(0.1) : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            Rectangle()
                                .fill(DesignSystem.Colors.primary)
                                .frame(height: 2)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.primary.opacity(0.02))
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search memories...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchText) { _, newValue in
                    viewModel.filterMemories(searchText: newValue)
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(16)
    }
    
    // MARK: - All Memories View
    
    private var allMemoriesView: some View {
        ScrollView {
            if viewModel.filteredMemories.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredMemories) { memory in
                        MemoryRowView(
                            memory: memory,
                            isSelected: selectedMemories.contains(memory.id),
                            isInSelectionMode: isInSelectionMode,
                            onDelete: {
                                Task {
                                    await viewModel.deleteMemory(memory)
                                }
                            },
                            onToggleSelection: {
                                toggleSelection(for: memory.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Memory Insights View
    
    private var memoryInsightsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overview stats
                MemoryStatsCard(
                    title: "Memory Overview",
                    stats: [
                        ("Total Memories", "\(viewModel.totalMemoryCount)"),
                        ("Average Importance", String(format: "%.1f", viewModel.averageImportance)),
                        ("Most Active Day", viewModel.mostActiveDay ?? "N/A"),
                        ("Memory Categories", "\(viewModel.categoryBreakdown.count)")
                    ]
                )
                
                // Category breakdown
                MemoryCategoryChart(categories: viewModel.categoryBreakdown)
                
                // Recent activity
                RecentMemoryActivityView(activities: viewModel.recentActivities)
                
                // Memory usage over time
                MemoryUsageTimelineView(usageData: viewModel.memoryUsageTimeline)
            }
            .padding(16)
        }
    }
    
    // MARK: - Memory Settings View
    
    private var memorySettingsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Automatic extraction toggle
                SettingsSection(title: "Memory Extraction") {
                    Toggle("Automatic Memory Extraction", isOn: $viewModel.automaticExtraction)
                        .onChange(of: viewModel.automaticExtraction) { _, newValue in
                            Task {
                                await viewModel.updateAutomaticExtraction(newValue)
                            }
                        }
                    
                    Text("When enabled, Gemi will automatically extract and store important information from your conversations and journal entries.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                // Memory limits
                SettingsSection(title: "Memory Limits") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Maximum Memories: \(Int(viewModel.maxMemoryCount))")
                            .font(.system(size: 14, weight: .medium))
                        
                        Slider(
                            value: $viewModel.maxMemoryCount,
                            in: 100...5000,
                            step: 100
                        )
                        .onChange(of: viewModel.maxMemoryCount) { _, newValue in
                            Task {
                                await viewModel.updateMaxMemoryCount(Int(newValue))
                            }
                        }
                        
                        Text("Older, less important memories will be automatically removed when this limit is reached.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Importance threshold
                SettingsSection(title: "Importance Threshold") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Minimum Importance: \(String(format: "%.1f", viewModel.minImportanceThreshold))")
                            .font(.system(size: 14, weight: .medium))
                        
                        Slider(
                            value: $viewModel.minImportanceThreshold,
                            in: 0.0...1.0,
                            step: 0.1
                        )
                        .onChange(of: viewModel.minImportanceThreshold) { _, newValue in
                            Task {
                                await viewModel.updateMinImportanceThreshold(newValue)
                            }
                        }
                        
                        Text("Memories below this importance score will not be stored.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Privacy & Security
                SettingsSection(title: "Privacy & Security") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.green)
                            Text("All memories are encrypted with AES-256")
                                .font(.system(size: 14))
                        }
                        
                        HStack {
                            Image(systemName: "internaldrive.fill")
                                .foregroundStyle(.blue)
                            Text("Stored locally on your device only")
                                .font(.system(size: 14))
                        }
                        
                        HStack {
                            Image(systemName: "icloud.slash.fill")
                                .foregroundStyle(.orange)
                            Text("Never uploaded to any server")
                                .font(.system(size: 14))
                        }
                    }
                }
                
                // Danger zone
                SettingsSection(title: "Danger Zone") {
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Clear All Memories", systemImage: "trash")
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") {
                dismiss()
            }
        }
        
        ToolbarItem(placement: .primaryAction) {
            if selectedTab == .all {
                Menu {
                    Button {
                        withAnimation {
                            isInSelectionMode.toggle()
                            if !isInSelectionMode {
                                selectedMemories.removeAll()
                            }
                        }
                    } label: {
                        Label(
                            isInSelectionMode ? "Cancel Selection" : "Select",
                            systemImage: "checkmark.circle"
                        )
                    }
                    
                    if isInSelectionMode && !selectedMemories.isEmpty {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteMemories(Array(selectedMemories))
                                selectedMemories.removeAll()
                                isInSelectionMode = false
                            }
                        } label: {
                            Label("Delete Selected", systemImage: "trash")
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("Export Memories", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Memories Yet")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("Gemi will start building memories as you write and chat")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func toggleSelection(for memoryId: UUID) {
        if selectedMemories.contains(memoryId) {
            selectedMemories.remove(memoryId)
        } else {
            selectedMemories.insert(memoryId)
        }
    }
}

// MARK: - Memory Tab

enum MemoryTab: String, CaseIterable {
    case all = "All"
    case insights = "Insights"
    case settings = "Settings"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .insights: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Memory Row View

struct MemoryRowView: View {
    let memory: Memory
    let isSelected: Bool
    let isInSelectionMode: Bool
    let onDelete: () -> Void
    let onToggleSelection: () -> Void
    
    @State private var showingDetail = false
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            if isInSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? DesignSystem.Colors.primary : .secondary)
                        .font(.system(size: 22))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Memory content
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Label(memory.memoryType.displayName, systemImage: memory.memoryType.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(memoryTypeColor)
                    
                    Spacer()
                    
                    // Importance indicator
                    ImportanceIndicator(score: memory.importance)
                    
                    // Pinned indicator
                    if memory.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                    }
                }
                
                // Content
                Text(memory.content)
                    .font(.system(size: 14))
                    .lineLimit(showingDetail ? nil : 2)
                    .foregroundStyle(.primary)
                
                // Metadata
                HStack(spacing: 16) {
                    // Created date
                    Label(
                        RelativeDateTimeFormatter().localizedString(for: memory.createdAt, relativeTo: Date()),
                        systemImage: "calendar"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    
                    // Last accessed
                    if memory.lastAccessedAt > memory.createdAt {
                        Label(
                            "Used \(RelativeDateTimeFormatter().localizedString(for: memory.lastAccessedAt, relativeTo: Date()))",
                            systemImage: "clock"
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }
                    
                    // Source link
                    if memory.sourceEntryId != nil {
                        Button {
                            // Navigate to source
                        } label: {
                            Label("View Source", systemImage: "arrow.right.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(DesignSystem.Colors.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Tags
                if !memory.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(memory.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 11))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        )
        .offset(x: offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isInSelectionMode {
                        offset = min(0, value.translation.width)
                    }
                }
                .onEnded { value in
                    if value.translation.width < -100 {
                        withAnimation {
                            offset = -1000
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDelete()
                        }
                    } else {
                        withAnimation {
                            offset = 0
                        }
                    }
                }
        )
        .onTapGesture {
            if isInSelectionMode {
                onToggleSelection()
            } else {
                withAnimation {
                    showingDetail.toggle()
                }
            }
        }
    }
    
    private var memoryTypeColor: Color {
        switch memory.memoryType {
        case .conversation, .conversationFact: return .blue
        case .journalFact: return .purple
        case .userProvided: return .green
        case .reflection: return .orange
        }
    }
}

// MARK: - Importance Indicator

struct ImportanceIndicator: View {
    let score: Float
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(Float(index) < score * 5 ? Color.yellow : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            
            content
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.03))
                )
        }
    }
}

// MARK: - Memory Stats Card

struct MemoryStatsCard: View {
    let title: String
    let stats: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(stats, id: \.0) { stat in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stat.1)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(DesignSystem.Colors.primary)
                        
                        Text(stat.0)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - Memory Category Chart

struct MemoryCategoryChart: View {
    let categories: [(MemoryType, Int)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Memory Categories")
                .font(.system(size: 18, weight: .semibold))
            
            VStack(spacing: 12) {
                ForEach(categories, id: \.0) { category in
                    HStack {
                        Label(category.0.displayName, systemImage: category.0.icon)
                            .font(.system(size: 14))
                        
                        Spacer()
                        
                        Text("\(category.1)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - Recent Memory Activity View

struct RecentMemoryActivityView: View {
    let activities: [MemoryActivity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.system(size: 18, weight: .semibold))
            
            if activities.isEmpty {
                Text("No recent memory activity")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(activities) { activity in
                        HStack(spacing: 12) {
                            Image(systemName: activity.icon)
                                .foregroundStyle(activity.color)
                                .frame(width: 32, height: 32)
                                .background(activity.color.opacity(0.1))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.description)
                                    .font(.system(size: 14))
                                
                                Text(RelativeDateTimeFormatter().localizedString(for: activity.date, relativeTo: Date()))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - Memory Usage Timeline View

struct MemoryUsageTimelineView: View {
    let usageData: [MemoryUsageData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Memory Usage Over Time")
                .font(.system(size: 18, weight: .semibold))
            
            // Simple bar chart
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(usageData) { data in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(DesignSystem.Colors.primary.opacity(0.7))
                            .frame(width: 20, height: CGFloat(data.count) * 2)
                        
                        Text(data.label)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 120)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - Memory Export View

struct MemoryExportView: View {
    let memories: [Memory]
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat: ExportFormat = .markdown
    @State private var includeMetadata = true
    @State private var isExporting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Format selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Format")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Options
                Toggle("Include Metadata", isOn: $includeMetadata)
                
                // Preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.system(size: 16, weight: .semibold))
                    
                    ScrollView {
                        Text(generateExportPreview())
                            .font(.system(size: 12, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(height: 200)
                }
                
                Spacer()
                
                // Export button
                Button {
                    exportMemories()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text("Export \(memories.count) Memories")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DesignSystem.Colors.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isExporting)
            }
            .padding(24)
            .navigationTitle("Export Memories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func generateExportPreview() -> String {
        let sample = memories.prefix(3)
        switch exportFormat {
        case .markdown:
            return sample.map { memory in
                """
                ## \(memory.memoryType.displayName)
                \(memory.content)
                \(includeMetadata ? "\n_Created: \(memory.createdAt.formatted())_" : "")
                """
            }.joined(separator: "\n\n")
        case .json:
            return "[\n" + sample.map { memory in
                """
                  {
                    "type": "\(memory.memoryType.rawValue)",
                    "content": "\(memory.content.prefix(50))...",
                    \(includeMetadata ? "\"created\": \"\(memory.createdAt.formatted())\"," : "")
                    "importance": \(memory.importance)
                  }
                """
            }.joined(separator: ",\n") + "\n]"
        case .plainText:
            return sample.map { memory in
                """
                [\(memory.memoryType.displayName)]
                \(memory.content)
                \(includeMetadata ? "Created: \(memory.createdAt.formatted())" : "")
                """
            }.joined(separator: "\n---\n")
        }
    }
    
    private func exportMemories() {
        isExporting = true
        // Implementation for actual export
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isExporting = false
            dismiss()
        }
    }
    
    enum ExportFormat: String, CaseIterable {
        case markdown = "Markdown"
        case json = "JSON"
        case plainText = "Plain Text"
    }
}

// MARK: - Supporting Types

struct MemoryActivity: Identifiable {
    let id = UUID()
    let description: String
    let date: Date
    let icon: String
    let color: Color
}

struct MemoryUsageData: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

// MARK: - View Model

@MainActor
class MemoryPanelViewModel: ObservableObject {
    @Published var memories: [Memory] = []
    @Published var filteredMemories: [Memory] = []
    @Published var totalMemoryCount = 0
    @Published var averageImportance: Float = 0
    @Published var mostActiveDay: String?
    @Published var categoryBreakdown: [(MemoryType, Int)] = []
    @Published var recentActivities: [MemoryActivity] = []
    @Published var memoryUsageTimeline: [MemoryUsageData] = []
    
    // Settings
    @Published var automaticExtraction = true
    @Published var maxMemoryCount: Double = 1000
    @Published var minImportanceThreshold: Double = 0.1
    
    private let memoryStore = MemoryStore.shared
    private let databaseManager: DatabaseManager
    private let logger = Logger(subsystem: "com.chaehoshin.Gemi", category: "MemoryPanelViewModel")
    
    init() {
        do {
            self.databaseManager = try DatabaseManager.shared()
        } catch {
            fatalError("Failed to initialize DatabaseManager: \(error)")
        }
    }
    
    func loadMemories() async {
        do {
            // Load all memories
            memories = try await databaseManager.dbReader.read { db in
                try Memory.fetchAll(db)
            }
            
            filteredMemories = memories
            totalMemoryCount = memories.count
            
            // Calculate stats
            calculateStats()
            
            // Load recent activities
            loadRecentActivities()
            
            // Load usage timeline
            loadUsageTimeline()
            
        } catch {
            logger.error("Failed to load memories: \(error)")
        }
    }
    
    func filterMemories(searchText: String) {
        if searchText.isEmpty {
            filteredMemories = memories
        } else {
            filteredMemories = memories.filter { memory in
                memory.content.localizedCaseInsensitiveContains(searchText) ||
                memory.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                memory.memoryType.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func deleteMemory(_ memory: Memory) async {
        do {
            _ = try await databaseManager.dbWriter.write { db in
                try memory.delete(db)
            }
            
            await loadMemories()
        } catch {
            logger.error("Failed to delete memory: \(error)")
        }
    }
    
    func deleteMemories(_ memoryIds: [UUID]) async {
        do {
            _ = try await databaseManager.dbWriter.write { db in
                try Memory
                    .filter(memoryIds.contains(Memory.Columns.id))
                    .deleteAll(db)
            }
            
            await loadMemories()
        } catch {
            logger.error("Failed to delete memories: \(error)")
        }
    }
    
    func clearAllMemories() async {
        do {
            _ = try await databaseManager.dbWriter.write { db in
                try Memory.deleteAll(db)
            }
            
            await loadMemories()
        } catch {
            logger.error("Failed to clear all memories: \(error)")
        }
    }
    
    func updateAutomaticExtraction(_ enabled: Bool) async {
        // Save to settings
        UserDefaults.standard.set(enabled, forKey: "automaticMemoryExtraction")
    }
    
    func updateMaxMemoryCount(_ count: Int) async {
        // Save to settings
        UserDefaults.standard.set(count, forKey: "maxMemoryCount")
    }
    
    func updateMinImportanceThreshold(_ threshold: Double) async {
        // Save to settings
        UserDefaults.standard.set(threshold, forKey: "minImportanceThreshold")
    }
    
    private func calculateStats() {
        guard !memories.isEmpty else { return }
        
        // Average importance
        let totalImportance = memories.reduce(0) { $0 + $1.importance }
        averageImportance = totalImportance / Float(memories.count)
        
        // Category breakdown
        let grouped = Dictionary(grouping: memories) { $0.memoryType }
        categoryBreakdown = grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
        
        // Most active day
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dayGroups = Dictionary(grouping: memories) { memory in
            dateFormatter.string(from: memory.createdAt)
        }
        mostActiveDay = dayGroups.max { $0.value.count < $1.value.count }?.key
    }
    
    private func loadRecentActivities() {
        // Simulate recent activities
        recentActivities = [
            MemoryActivity(
                description: "Extracted from journal entry",
                date: Date().addingTimeInterval(-3600),
                icon: "book.pages",
                color: .purple
            ),
            MemoryActivity(
                description: "New conversation memory",
                date: Date().addingTimeInterval(-7200),
                icon: "bubble.left.and.bubble.right",
                color: .blue
            ),
            MemoryActivity(
                description: "Memory accessed in chat",
                date: Date().addingTimeInterval(-10800),
                icon: "clock",
                color: .green
            )
        ]
    }
    
    private func loadUsageTimeline() {
        // Simulate usage data
        memoryUsageTimeline = [
            MemoryUsageData(label: "Mon", count: 12),
            MemoryUsageData(label: "Tue", count: 18),
            MemoryUsageData(label: "Wed", count: 15),
            MemoryUsageData(label: "Thu", count: 22),
            MemoryUsageData(label: "Fri", count: 28),
            MemoryUsageData(label: "Sat", count: 20),
            MemoryUsageData(label: "Sun", count: 16)
        ]
    }
}

// MARK: - Preview

#Preview {
    MemoryPanelView()
}