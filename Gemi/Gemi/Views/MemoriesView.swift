import SwiftUI

struct MemoriesView: View {
    @StateObject private var viewModel = MemoryViewModel()
    @ObservedObject var memoryManager = MemoryManager.shared
    @State private var showingProcessingView = false
    
    var body: some View {
        ZStack {
            if memoryManager.memories.isEmpty && !memoryManager.isProcessing {
                emptyStateView
            } else {
                memoriesListView
            }
            
            if memoryManager.isProcessing && !showingProcessingView {
                processingOverlay
            }
        }
        .background(Theme.Colors.windowBackground)
        .sheet(isPresented: $showingProcessingView) {
            ProcessEntriesView()
                .frame(width: 480, height: 540)
        }
        // Removed: alert for deletion confirmation
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: Theme.largeSpacing) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Theme.Colors.primaryAccent.opacity(0.1), Theme.Colors.primaryAccent.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "brain")
                    .font(.system(size: 56))
                    .foregroundColor(Theme.Colors.primaryAccent)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.pulse, options: .repeating.speed(0.5))
            }
            
            VStack(spacing: Theme.spacing) {
                Text("No Memories Yet")
                    .font(Theme.Typography.title)
                
                Text("Gemi will extract and remember important details from your journal entries")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                
                Button {
                    showingProcessingView = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("Extract Memories from Journal")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Theme.Colors.primaryAccent, Theme.Colors.primaryAccent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Theme.Colors.primaryAccent.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        // Visual feedback handled by button style
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Memories List
    
    private var memoriesListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                memoryHeader
                
                // Filters
                filterBar
                    .padding(.horizontal)
                    .padding(.bottom)
                
                // Memory cards with staggered animation
                LazyVStack(spacing: Theme.spacing) {
                    ForEach(Array(viewModel.filteredMemories.enumerated()), id: \.element.id) { index, memory in
                        MemoryCard(
                            memory: memory,
                            onDelete: {
                                viewModel.deleteMemory(memory)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale)
                        ))
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.05),
                            value: viewModel.filteredMemories.count
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Header
    
    private var memoryHeader: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Image(systemName: "brain")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.Colors.primaryAccent)
                            .symbolRenderingMode(.hierarchical)
                        
                        Text("AI Memories")
                            .font(Theme.Typography.sectionHeader)
                    }
                    
                    Text("\(memoryManager.memories.count) memories extracted from your journal")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                // Memory statistics with equal-sized boxes
                if !memoryManager.memories.isEmpty {
                    HStack(spacing: 12) {
                        // Total count
                        VStack(spacing: 2) {
                            Text("\(memoryManager.memories.count)")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(Theme.Colors.primaryAccent)
                            Text("Total")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 80, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.Colors.primaryAccent.opacity(0.1))
                        )
                        
                        // Recent badge
                        let recentCount = memoryManager.memories.filter { 
                            Calendar.current.dateComponents([.day], from: $0.extractedAt, to: Date()).day ?? 0 < 7 
                        }.count
                        VStack(spacing: 2) {
                            Text("\(recentCount)")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(recentCount > 0 ? .green : .secondary)
                            Text("This Week")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 80, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(recentCount > 0 ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Search with animation
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .symbolEffect(.pulse, options: .speed(0.5), isActive: !viewModel.searchText.isEmpty)
                    TextField("Search memories...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 200)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    viewModel.searchText.isEmpty ? Color.clear : Theme.Colors.primaryAccent.opacity(0.3),
                                    lineWidth: 1.5
                                )
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: viewModel.searchText)
                
                Divider()
                    .frame(height: 30)
                
                // Clean markdown button
                Button {
                    Task {
                        await memoryManager.cleanMarkdownFromMemories()
                    }
                } label: {
                    Label("Clean Formatting", systemImage: "wand.and.stars")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Remove markdown formatting from all memories")
                
                Divider()
                    .frame(height: 30)
                
                // Sort order and Process Entries with equal size
                HStack(spacing: 12) {
                    // Sort order
                    Menu {
                        ForEach(MemoryViewModel.SortOrder.allCases, id: \.self) { order in
                            Button(order.rawValue) {
                                viewModel.sortOrder = order
                            }
                        }
                    } label: {
                        Label(viewModel.sortOrder.rawValue, systemImage: "arrow.up.arrow.down")
                            .font(.system(size: 14))
                            .frame(width: 120)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    
                    // Process entries button
                    if !memoryManager.memories.isEmpty {
                        Button {
                            showingProcessingView = true
                        } label: {
                            Label("Process", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14))
                                .frame(width: 120)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
            }
        }
    }
    
    // MARK: - Processing Overlay
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: Theme.spacing) {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                
                Text("Extracting memories from your journal...")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(Theme.Colors.cardBackground)
                    .shadow(color: Color.black.opacity(0.2), radius: 20)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

// MARK: - Memory Card

struct MemoryCard: View {
    let memory: Memory
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                // Header with delete button
                HStack {
                    // Date extracted
                    Text(memory.extractedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Spacer()
                    
                    if isHovered {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                
                // Content with expandable behavior
                Text(memory.content)
                    .font(Theme.Typography.body)
                    .lineLimit(isExpanded ? nil : 3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
                
                // Show expand/collapse indicator if content is long
                if memory.content.count > 150 {
                    HStack {
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up.circle" : "chevron.down.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(Theme.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                    .fill(isHovered ? Theme.Colors.cardBackground : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .confirmationDialog(
            "Delete Memory?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                withAnimation(.easeOut(duration: 0.3)) {
                    onDelete()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This memory will be permanently deleted.")
        }
    }
}

// MARK: - Process Entries View

struct ProcessEntriesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var totalCount = 0
    @State private var selectedTimeRange: TimeRange = .lastWeek
    @State private var extractedMemoriesCount = 0
    
    enum TimeRange: String, CaseIterable {
        case lastWeek = "Last Week"
        case lastMonth = "Last Month"
        case lastThreeMonths = "Last 3 Months"
        case all = "All Entries"
        
        var icon: String {
            switch self {
            case .lastWeek: return "calendar"
            case .lastMonth: return "calendar.badge.clock"
            case .lastThreeMonths: return "calendar.circle"
            case .all: return "tray.full"
            }
        }
        
        var description: String {
            switch self {
            case .lastWeek: return "Process entries from the past 7 days"
            case .lastMonth: return "Process entries from the past month"
            case .lastThreeMonths: return "Process entries from the past 3 months"
            case .all: return "Process all journal entries"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isProcessing {
                // Processing View
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Extracting Memories")
                            .font(.system(size: 22, weight: .semibold))
                        Text("Analyzing your journal entries...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 40)
                    
                    // Progress Circle
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: totalCount > 0 ? CGFloat(processedCount) / CGFloat(totalCount) : 0)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.Colors.primaryAccent, Theme.Colors.primaryAccent.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: processedCount)
                        
                        // Percentage and icon
                        VStack(spacing: 4) {
                            Image(systemName: "brain")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.Colors.primaryAccent)
                                .symbolRenderingMode(.hierarchical)
                                .symbolEffect(.pulse, options: .speed(0.8).repeating, isActive: isProcessing)
                            
                            Text("\(Int((totalCount > 0 ? Double(processedCount) / Double(totalCount) : 0) * 100))%")
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                    
                    // Status Text
                    VStack(spacing: 12) {
                        Text("Processing entry \(processedCount) of \(totalCount)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.top, 24) // Add space between progress circle and text
                        
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.primaryAccent)
                                .symbolEffect(.pulse, options: .speed(1.5).repeating, isActive: isProcessing)
                            
                            Text("\(extractedMemoriesCount) memories extracted")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Theme.Colors.primaryAccent)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.primaryAccent.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Theme.Colors.primaryAccent.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    
                    Spacer()
                        .frame(height: 40) // Fixed height spacer instead of flexible
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))
            } else {
                // Selection View
                VStack(spacing: 0) {
                    // Header Section
                    VStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Theme.Colors.primaryAccent.opacity(0.15), Theme.Colors.primaryAccent.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 64, height: 64)
                            
                            Image(systemName: "brain")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.Colors.primaryAccent)
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Extract Key Memories")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("AI will analyze your entries and remember important details")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                        }
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 24)
                    
                    Divider()
                        .padding(.horizontal, 24)
                    
                    // Time Range Selection
                    VStack(spacing: 16) {
                        Text("Select time range")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 8) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                CompactTimeRangeOption(
                                    range: range,
                                    isSelected: selectedTimeRange == range,
                                    onSelect: { selectedTimeRange = range }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 24)
                    
                    Spacer()
                    
                    // Action Button
                    Button {
                        processEntries()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 14))
                            Text("Start Extraction")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Theme.Colors.primaryAccent, Theme.Colors.primaryAccent.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Theme.Colors.primaryAccent.opacity(0.25), radius: 6, y: 3)
                    }
                    .buttonStyle(AnimatedButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
        }
        .padding(.top, 8) // Add small top padding for sheet handle
        .background(Theme.Colors.windowBackground)
        .animation(Theme.gentleSpring, value: isProcessing)
    }
    
    private func processEntries() {
        Task {
            isProcessing = true
            extractedMemoriesCount = 0
            
            // Get entries based on time range
            let entries = await getEntriesForTimeRange()
            totalCount = entries.count
            
            // Process each entry
            for (index, entry) in entries.enumerated() {
                processedCount = index + 1
                
                // Get count before processing
                let beforeCount = MemoryManager.shared.memories.count
                
                await GemiAICoordinator.shared.processJournalEntry(entry)
                
                // Update extracted count
                let afterCount = MemoryManager.shared.memories.count
                extractedMemoriesCount += max(0, afterCount - beforeCount)
                
                // Small delay to avoid overwhelming the API
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            isProcessing = false
            dismiss()
        }
    }
    
    private func getEntriesForTimeRange() async -> [JournalEntry] {
        let allEntries = try? await DatabaseManager.shared.loadEntries()
        guard let entries = allEntries else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        
        let cutoffDate: Date
        switch selectedTimeRange {
        case .lastWeek:
            cutoffDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .lastMonth:
            cutoffDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .lastThreeMonths:
            cutoffDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .all:
            return entries
        }
        
        return entries.filter { $0.createdAt >= cutoffDate }
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(Theme.Colors.primaryAccent)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }
}

struct TimeRangeOption: View {
    let range: ProcessEntriesView.TimeRange
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: range.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? Theme.Colors.primaryAccent : .secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(range.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .primary : .secondary)
                    
                    Text(range.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.primaryAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.Colors.primaryAccent.opacity(0.1) : Color.secondary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Theme.Colors.primaryAccent : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct CompactTimeRangeOption: View {
    let range: ProcessEntriesView.TimeRange
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: range.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? Theme.Colors.primaryAccent : .secondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .primary : .primary.opacity(0.9))
                    
                    Text(range.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.primaryAccent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.Colors.primaryAccent.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.08) : Color.secondary.opacity(0.05)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Theme.Colors.primaryAccent.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}