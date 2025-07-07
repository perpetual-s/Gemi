import SwiftUI

struct MemoriesView: View {
    @StateObject private var viewModel = MemoryViewModel()
    @ObservedObject var memoryManager = MemoryManager.shared
    @State private var showingProcessingView = false
    @State private var selectedMemory: Memory?
    @State private var showingDeleteAlert = false
    @State private var memoryToDelete: Memory?
    
    var body: some View {
        ZStack {
            if memoryManager.memories.isEmpty && !memoryManager.isProcessing {
                emptyStateView
            } else {
                memoriesListView
            }
            
            if memoryManager.isProcessing {
                processingOverlay
            }
        }
        .background(Theme.Colors.windowBackground)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if !memoryManager.memories.isEmpty {
                    Button {
                        showingProcessingView = true
                    } label: {
                        Text("Process Entries")
                    }
                }
            }
        }
        .sheet(isPresented: $showingProcessingView) {
            ProcessEntriesView()
        }
        .alert("Delete Memory", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let memory = memoryToDelete {
                    viewModel.deleteMemory(memory)
                }
            }
        } message: {
            Text("Are you sure you want to delete this memory? This action cannot be undone.")
        }
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
                    Text("Process Journal Entries")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.primaryAccent)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top)
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
                
                // Memory cards
                LazyVStack(spacing: Theme.spacing) {
                    ForEach(viewModel.filteredMemories) { memory in
                        MemoryCard(
                            memory: memory,
                            onTap: { selectedMemory = memory },
                            onDelete: {
                                memoryToDelete = memory
                                showingDeleteAlert = true
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale)
                        ))
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
                            .font(Theme.Typography.largeTitle)
                    }
                    
                    Text("\(memoryManager.memories.count) memories extracted from your journal")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                // Simple count badge
                if !memoryManager.memories.isEmpty {
                    Text("\(memoryManager.memories.count)")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.primaryAccent.opacity(0.1))
                        )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search memories...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 200)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
                
                Divider()
                    .frame(height: 30)
                
                // Sort order
                Menu {
                    ForEach(MemoryViewModel.SortOrder.allCases, id: \.self) { order in
                        Button(order.rawValue) {
                            viewModel.sortOrder = order
                        }
                    }
                } label: {
                    Label(viewModel.sortOrder.rawValue, systemImage: "arrow.up.arrow.down")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - Processing Overlay
    
    private var processingOverlay: some View {
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
                .shadow(color: Color.black.opacity(0.1), radius: 10)
        )
    }
}

// MARK: - Memory Card

struct MemoryCard: View {
    let memory: Memory
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
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
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                
                // Content
                Text(memory.content)
                    .font(Theme.Typography.body)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
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
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extract Memories")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Use AI to find important details in your journal")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.6))
                        .background(Circle().fill(Color.clear))
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
            
            // Content
            VStack(spacing: 0) {
                // Icon and description
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Theme.Colors.primaryAccent.opacity(0.2), Theme.Colors.primaryAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "brain")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.Colors.primaryAccent)
                            .symbolRenderingMode(.hierarchical)
                    }
                    
                    Text("Gemi will analyze your entries and extract key memories")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 30)
                
                // Time range selection
                VStack(spacing: 16) {
                    Text("Select time range")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            TimeRangeOption(
                                range: range,
                                isSelected: selectedTimeRange == range,
                                onSelect: { selectedTimeRange = range }
                            )
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.top, 30)
                
                Spacer()
                
                // Progress or action button
                if isProcessing {
                    VStack(spacing: 16) {
                        // Progress indicator
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                                .frame(width: 60, height: 60)
                            
                            Circle()
                                .trim(from: 0, to: totalCount > 0 ? CGFloat(processedCount) / CGFloat(totalCount) : 0)
                                .stroke(Theme.Colors.primaryAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut, value: processedCount)
                            
                            Text("\(Int((totalCount > 0 ? Double(processedCount) / Double(totalCount) : 0) * 100))%")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        
                        VStack(spacing: 4) {
                            Text("Processing entry \(processedCount) of \(totalCount)")
                                .font(.system(size: 14, weight: .medium))
                            Text("\(extractedMemoriesCount) memories extracted")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 40)
                } else {
                    Button {
                        processEntries()
                    } label: {
                        Text("Start Extraction")
                            .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.primaryAccent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 30)
                }
            }
        }
        .frame(width: 520, height: 600)
        .background(Theme.Colors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.15), radius: 20)
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