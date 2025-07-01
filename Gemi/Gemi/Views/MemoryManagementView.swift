//
//  MemoryManagementView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import SwiftUI

/// Beautiful memory management interface that allows users to view and control their AI memories
struct MemoryManagementView: View {
    @State private var memoryStore: MemoryStore
    @State private var memories: [Memory] = []
    @State private var selectedMemoryType: MemoryType?
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var memoryToDelete: Memory?
    @State private var showClearAllConfirmation: Bool = false
    @State private var memoryStats: MemoryStats?
    @State private var selectedMemory: Memory?
    @State private var showMemoryDetail: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    init(memoryStore: MemoryStore) {
        self._memoryStore = State(initialValue: memoryStore)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
                .opacity(0.1)
            
            // Filter bar
            filterBar
            
            // Content
            if isLoading {
                loadingView
            } else if filteredMemories.isEmpty {
                emptyStateView
            } else {
                memoryListView
            }
            
            // Stats bar
            statsBar
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(DesignSystem.Colors.backgroundPrimary)
        .task {
            await loadMemories()
            await loadStats()
        }
        .sheet(isPresented: $showMemoryDetail) {
            if let memory = selectedMemory {
                MemoryDetailView(memory: memory, memoryStore: memoryStore)
            }
        }
        .alert("Delete Memory?", isPresented: $showDeleteConfirmation, presenting: memoryToDelete) { memory in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteMemory(memory)
                }
            }
        } message: { memory in
            Text("Are you sure you want to delete this memory? This action cannot be undone.")
        }
        .alert("Clear All Memories?", isPresented: $showClearAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                Task {
                    await clearAllMemories()
                }
            }
        } message: {
            Text("This will permanently delete all memories. This action cannot be undone.")
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Memory Management")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Control what Gemi remembers about you")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Clear all button
            Button {
                showClearAllConfirmation = true
            } label: {
                Label("Clear All", systemImage: "trash")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.error)
            }
            .gemiSubtleButton()
            
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(DesignSystem.Colors.hover))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        HStack(spacing: 16) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                TextField("Search memories...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.body)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                    .fill(DesignSystem.Colors.backgroundSecondary)
            )
            .frame(maxWidth: 300)
            
            // Type filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterPill(
                        title: "All Types",
                        isSelected: selectedMemoryType == nil,
                        action: { selectedMemoryType = nil }
                    )
                    
                    ForEach(MemoryType.allCases, id: \.self) { type in
                        FilterPill(
                            title: type.displayName,
                            icon: type.icon,
                            isSelected: selectedMemoryType == type,
                            action: { selectedMemoryType = type }
                        )
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(DesignSystem.Colors.backgroundSecondary.opacity(0.5))
    }
    
    // MARK: - Memory List
    
    private var memoryListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMemories) { memory in
                    MemoryRow(
                        memory: memory,
                        onTap: {
                            selectedMemory = memory
                            showMemoryDetail = true
                        },
                        onDelete: {
                            memoryToDelete = memory
                            showDeleteConfirmation = true
                        },
                        onTogglePin: {
                            Task {
                                await togglePin(memory)
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
            
            Text("Loading memories...")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Illustration
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: searchText.isEmpty ? "brain" : "magnifyingglass")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No memories yet" : "No results found")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text(searchText.isEmpty ? 
                     "Start chatting with Gemi or writing in your journal to create memories" :
                     "Try a different search term")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        HStack(spacing: 32) {
            if let stats = memoryStats {
                StatItem(
                    label: "Total Memories",
                    value: "\(stats.totalCount)",
                    icon: "brain"
                )
                
                StatItem(
                    label: "Pinned",
                    value: "\(stats.pinnedCount)",
                    icon: "pin.fill"
                )
                
                if let oldest = stats.oldestMemoryDate {
                    StatItem(
                        label: "Remembering Since",
                        value: oldest.formatted(date: .abbreviated, time: .omitted),
                        icon: "calendar"
                    )
                }
                
                StatItem(
                    label: "Daily Average",
                    value: String(format: "%.1f", stats.averageMemoriesPerDay),
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(DesignSystem.Colors.backgroundSecondary.opacity(0.5))
    }
    
    // MARK: - Computed Properties
    
    private var filteredMemories: [Memory] {
        memories.filter { memory in
            let matchesType = selectedMemoryType == nil || memory.memoryType == selectedMemoryType
            let matchesSearch = searchText.isEmpty || 
                memory.content.localizedCaseInsensitiveContains(searchText) ||
                memory.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            
            return matchesType && matchesSearch
        }
    }
    
    // MARK: - Methods
    
    private func loadMemories() async {
        isLoading = true
        do {
            memories = try await memoryStore.getAllMemories(limit: 200)
        } catch {
            print("Failed to load memories: \(error)")
        }
        isLoading = false
    }
    
    private func loadStats() async {
        do {
            memoryStats = try await memoryStore.getMemoryStats()
        } catch {
            print("Failed to load stats: \(error)")
        }
    }
    
    private func deleteMemory(_ memory: Memory) async {
        do {
            try await memoryStore.deleteMemory(id: memory.id)
            await loadMemories()
            await loadStats()
        } catch {
            print("Failed to delete memory: \(error)")
        }
    }
    
    private func togglePin(_ memory: Memory) async {
        do {
            try await memoryStore.toggleMemoryPin(id: memory.id)
            await loadMemories()
        } catch {
            print("Failed to toggle pin: \(error)")
        }
    }
    
    private func clearAllMemories() async {
        do {
            try await memoryStore.clearAllMemories(ofType: selectedMemoryType)
            await loadMemories()
            await loadStats()
        } catch {
            print("Failed to clear memories: \(error)")
        }
    }
}

// MARK: - Memory Row

struct MemoryRow: View {
    let memory: Memory
    let onTap: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                // Type icon
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: memory.memoryType.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(DesignSystem.Colors.primary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(memory.content)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 12) {
                        // Date
                        Label(memory.relativeTimeString, systemImage: "clock")
                            .font(DesignSystem.Typography.footnote)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        
                        // Tags
                        if !memory.tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(memory.tags.prefix(3), id: \.self) { tag in
                                    Text(tag)
                                        .font(DesignSystem.Typography.caption1)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(DesignSystem.Colors.hover)
                                        )
                                }
                                
                                if memory.tags.count > 3 {
                                    Text("+\(memory.tags.count - 3)")
                                        .font(DesignSystem.Typography.caption1)
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Importance indicator
                        ImportanceIndicator(importance: memory.decayedImportance)
                    }
                }
                
                // Actions
                if isHovered {
                    HStack(spacing: 8) {
                        Button(action: onTogglePin) {
                            Image(systemName: memory.isPinned ? "pin.fill" : "pin")
                                .foregroundStyle(memory.isPinned ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundStyle(DesignSystem.Colors.error)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                    .fill(DesignSystem.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                            .stroke(
                                memory.isPinned ? DesignSystem.Colors.primary.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: DesignSystem.Colors.shadowLight.color,
                radius: isHovered ? 8 : 4,
                y: isHovered ? 4 : 2
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(DesignSystem.Typography.footnote)
            }
            .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.hover)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text(label)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
    }
}

// MARK: - Importance Indicator

struct ImportanceIndicator: View {
    let importance: Float
    
    private var color: Color {
        if importance > 0.7 {
            return DesignSystem.Colors.primary
        } else if importance > 0.4 {
            return DesignSystem.Colors.warning
        } else {
            return DesignSystem.Colors.textTertiary
        }
    }
    
    private var fillCount: Int {
        Int(ceil(importance * 3))
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index < fillCount ? color : DesignSystem.Colors.hover)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Memory Detail View

struct MemoryDetailView: View {
    let memory: Memory
    let memoryStore: MemoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var importance: Float
    
    init(memory: Memory, memoryStore: MemoryStore) {
        self.memory = memory
        self.memoryStore = memoryStore
        self._importance = State(initialValue: memory.importance)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Memory Details")
                    .font(DesignSystem.Typography.title3)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .gemiPrimaryButton()
            }
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Memory content
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Content", systemImage: "text.quote")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        Text(memory.content)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                                    .fill(DesignSystem.Colors.backgroundSecondary)
                            )
                    }
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 16) {
                        MetadataRow(label: "Type", value: memory.memoryType.displayName, icon: memory.memoryType.icon)
                        MetadataRow(label: "Created", value: memory.createdAt.formatted(), icon: "calendar")
                        MetadataRow(label: "Last Accessed", value: memory.lastAccessedAt.formatted(), icon: "clock")
                        
                        if !memory.tags.isEmpty {
                            HStack(alignment: .top) {
                                Label("Tags", systemImage: "tag")
                                    .font(DesignSystem.Typography.footnote)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .frame(width: 120, alignment: .leading)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(memory.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(DesignSystem.Typography.footnote)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(DesignSystem.Colors.hover)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    
                    // Importance slider
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Importance", systemImage: "star")
                                .font(DesignSystem.Typography.headline)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            
                            Spacer()
                            
                            Text("\(Int(importance * 100))%")
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }
                        
                        Slider(value: $importance, in: 0...1)
                            .onChange(of: importance) { _, newValue in
                                Task {
                                    try await memoryStore.updateMemoryImportance(id: memory.id, importance: newValue)
                                }
                            }
                    }
                }
            }
        }
        .padding(32)
        .frame(width: 600, height: 500)
        .background(DesignSystem.Colors.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Components.radiusLarge))
    }
}

// MARK: - Metadata Row

struct MetadataRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(DesignSystem.Typography.footnote)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
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
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}