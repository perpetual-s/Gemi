//
//  MemoryManagementView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

/// MemoryManagementView allows users to view and manage what Gemi remembers
struct MemoryManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var memories: [Memory] = []
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var memoryToDelete: Memory?
    @State private var isLoading = true
    @State private var memoryStats: MemoryStats?
    @State private var archiveStats: ArchiveStats?
    @State private var memoryLimit = MemoryStore.defaultMemoryLimit
    @State private var showingExportAlert = false
    @State private var exportURL: URL?
    @State private var showingArchiveWarning = false
    @State private var selectedTab = 0  // 0: Active, 1: Settings
    
    var filteredMemories: [Memory] {
        if searchText.isEmpty {
            return memories
        }
        return memories.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Tab selection
            Picker("", selection: $selectedTab) {
                Text("Active Memories").tag(0)
                Text("Settings & Archives").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.bottom, DesignSystem.Spacing.medium)
            
            // Content
            if selectedTab == 0 {
                if isLoading {
                    ProgressView("Loading memories...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if memories.isEmpty {
                    emptyStateView
                } else {
                    memoryListView
                }
            } else {
                settingsView
            }
        }
        .frame(width: 800, height: 600)
        .background(DesignSystem.Colors.backgroundPrimary)
        .task {
            await loadMemories()
            await loadStats()
            memoryLimit = UserDefaults.standard.integer(forKey: MemoryStore.memoryLimitKey)
            if memoryLimit == 0 {
                memoryLimit = MemoryStore.defaultMemoryLimit
            }
        }
        .alert("Delete Memory", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let memory = memoryToDelete {
                    Task {
                        await deleteMemory(memory)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this memory? This action cannot be undone.")
        }
        .alert("Memory Export", isPresented: $showingExportAlert) {
            Button("OK") { }
        } message: {
            if let url = exportURL {
                Text("Memories exported successfully to: \(url.lastPathComponent)")
            } else {
                Text("Failed to export memories")
            }
        }
        .alert("Memory Limit Reached", isPresented: $showingArchiveWarning) {
            Button("Archive Old Memories", role: .destructive) {
                Task {
                    await archiveOldMemories()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have reached the memory limit of \(memoryLimit). Older, less important memories will be archived to make room for new ones. Archived memories can be exported but won't be used in conversations.")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                    Text("Memory Management")
                        .font(DesignSystem.Typography.title1)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Text("Control what Gemi remembers about your journey")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(DesignSystem.Spacing.large)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                
                TextField("Search memories...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignSystem.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                    .fill(DesignSystem.Colors.backgroundSecondary)
            )
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.bottom, DesignSystem.Spacing.medium)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
            
            Text("No memories yet")
                .font(DesignSystem.Typography.title2)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Text("Gemi will remember important details from your journal entries")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var memoryListView: some View {
        VStack(spacing: 0) {
            // Stats bar
            HStack {
                HStack(spacing: DesignSystem.Spacing.small) {
                    Text("\(filteredMemories.count) memories")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    
                    if let stats = memoryStats {
                        Text("• \(stats.pinnedCount) pinned")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: DesignSystem.Spacing.medium) {
                    Button(action: { Task { await exportMemories() } }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(DesignSystem.Typography.caption1)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { Task { await clearAllMemories() } }) {
                        Label("Clear All", systemImage: "trash")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.vertical, DesignSystem.Spacing.small)
            
            // Memory list
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.small) {
                    ForEach(filteredMemories) { memory in
                        MemoryRow(memory: memory) {
                            memoryToDelete = memory
                            showingDeleteConfirmation = true
                        } onTogglePin: {
                            Task {
                                await togglePin(memory)
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.large)
            }
        }
    }
    
    private var settingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                // Memory Limit Settings
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    Text("Memory Limit")
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Text("Set the maximum number of active memories Gemi will keep. Older memories will be archived when this limit is reached.")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    
                    HStack {
                        TextField("Memory limit", value: $memoryLimit, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .onChange(of: memoryLimit) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: MemoryStore.memoryLimitKey)
                            }
                        
                        Text("memories")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        Spacer()
                        
                        if let stats = memoryStats {
                            Text("Current: \(stats.totalCount)")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundStyle(stats.totalCount > memoryLimit ? .red : DesignSystem.Colors.textTertiary)
                        }
                    }
                }
                
                Divider()
                
                // Archive Statistics
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    Text("Archive Statistics")
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    if let archiveStats = archiveStats {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            HStack {
                                Label("Total Archives:", systemImage: "archivebox")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                Spacer()
                                Text("\(archiveStats.totalArchives)")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                            }
                            
                            HStack {
                                Label("Archived Memories:", systemImage: "doc.on.doc")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                Spacer()
                                Text("\(archiveStats.totalArchivedMemories)")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                            }
                            
                            if let oldest = archiveStats.oldestArchive {
                                HStack {
                                    Label("Oldest Archive:", systemImage: "calendar")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    Spacer()
                                    Text(oldest, style: .date)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                }
                            }
                        }
                    } else {
                        Text("No archives yet")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    
                    HStack {
                        Button("Export All (with Archives)") {
                            Task {
                                await exportMemories(includeArchived: true)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                // Memory Statistics
                if let stats = memoryStats {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                        Text("Memory Breakdown")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        
                        ForEach(MemoryType.allCases, id: \.self) { type in
                            if let count = stats.typeCounts[type], count > 0 {
                                HStack {
                                    Label(type.displayName, systemImage: type.icon)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    Spacer()
                                    Text("\(count)")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                }
                            }
                        }
                        
                        if stats.totalCount > 0 {
                            HStack {
                                Text("Average per day:")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                Spacer()
                                Text(String(format: "%.1f", stats.averageMemoriesPerDay))
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.large)
        }
    }
    
    // MARK: - Methods
    
    private func loadMemories() async {
        isLoading = true
        do {
            memories = try await MemoryStore.shared.getAllMemories(limit: 100)
        } catch {
            print("Failed to load memories: \(error)")
        }
        isLoading = false
    }
    
    private func loadStats() async {
        do {
            memoryStats = try await MemoryStore.shared.getMemoryStats()
            archiveStats = try await MemoryStore.shared.getArchiveStats()
            
            // Check if we should show archive warning
            if let stats = memoryStats, stats.totalCount >= memoryLimit {
                showingArchiveWarning = true
            }
        } catch {
            print("Failed to load stats: \(error)")
        }
    }
    
    private func deleteMemory(_ memory: Memory) async {
        do {
            try await MemoryStore.shared.deleteMemory(id: memory.id)
            await loadMemories()
            await loadStats()
        } catch {
            print("Failed to delete memory: \(error)")
        }
    }
    
    private func togglePin(_ memory: Memory) async {
        do {
            try await MemoryStore.shared.toggleMemoryPin(id: memory.id)
            await loadMemories()
            await loadStats()
        } catch {
            print("Failed to toggle pin: \(error)")
        }
    }
    
    private func clearAllMemories() async {
        do {
            try await MemoryStore.shared.clearAllMemories()
            await loadMemories()
            await loadStats()
        } catch {
            print("Failed to clear memories: \(error)")
        }
    }
    
    private func exportMemories(includeArchived: Bool = false) async {
        do {
            exportURL = try await MemoryStore.shared.exportMemories(includeArchived: includeArchived)
            showingExportAlert = true
        } catch {
            print("Failed to export memories: \(error)")
            showingExportAlert = true
        }
    }
    
    private func archiveOldMemories() async {
        // This will be triggered automatically when adding new memories
        await loadMemories()
        await loadStats()
    }
}


// MARK: - Memory Row

struct MemoryRow: View {
    let memory: Memory
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            // Type icon
            Image(systemName: memory.memoryType.icon)
                .font(.system(size: 16))
                .foregroundStyle(memoryTypeColor(memory.memoryType))
                .frame(width: 24, height: 24)
            
            // Content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                HStack {
                    Text(memory.content)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                    
                    if memory.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                    }
                }
                
                HStack(spacing: DesignSystem.Spacing.small) {
                    Text(memory.createdAt, style: .relative)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    
                    Text("• Importance: \(String(format: "%.1f", memory.importance))")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    
                    if !memory.tags.isEmpty {
                        Text("• \(memory.tags.joined(separator: ", "))")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: DesignSystem.Spacing.small) {
                Button(action: onTogglePin) {
                    Image(systemName: memory.isPinned ? "pin.slash" : "pin")
                        .font(.system(size: 14))
                        .foregroundStyle(memory.isPinned ? .orange : DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                .fill(isHovered ? DesignSystem.Colors.backgroundTertiary : DesignSystem.Colors.backgroundSecondary)
        )
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovered = hovering
            }
        }
    }
    
    private func memoryTypeColor(_ type: MemoryType) -> Color {
        switch type {
        case .conversation: return .blue
        case .journalFact: return .purple
        case .userProvided: return .pink
        case .reflection: return .orange
        case .conversationFact: return .green
        }
    }
}

// MARK: - Preview

#Preview {
    MemoryManagementView()
}