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
                        Label("Process Entries", systemImage: "sparkles")
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
                    Label("Process Journal Entries", systemImage: "sparkles")
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
                            },
                            onUpdateImportance: { importance in
                                viewModel.updateImportance(for: memory, importance: importance)
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
                
                // Statistics
                if !memoryManager.memories.isEmpty {
                    HStack(spacing: 20) {
                        StatBadge(
                            icon: "star.fill",
                            value: "\(memoryManager.memories.filter { $0.importance >= 4 }.count)",
                            label: "Important"
                        )
                        
                        if let mostCommonCategory = memoryManager.memoriesByCategory().max(by: { $0.value.count < $1.value.count })?.key {
                            StatBadge(
                                icon: "tag.fill",
                                value: mostCommonCategory.rawValue,
                                label: "Top Category"
                            )
                        }
                    }
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
                
                // Category filter
                Menu {
                    Button("All Categories") {
                        viewModel.selectedCategory = nil
                    }
                    Divider()
                    ForEach(Memory.MemoryCategory.allCases, id: \.self) { category in
                        Button(category.rawValue) {
                            viewModel.selectedCategory = category
                        }
                    }
                } label: {
                    Label(
                        viewModel.selectedCategory?.rawValue ?? "All Categories",
                        systemImage: "tag"
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(viewModel.selectedCategory != nil ? Theme.Colors.primaryAccent.opacity(0.1) : Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                }
                
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
                
                // High importance filter
                Toggle(isOn: $viewModel.showOnlyHighImportance) {
                    Label("Important Only", systemImage: "star.fill")
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(viewModel.showOnlyHighImportance ? Theme.Colors.primaryAccent.opacity(0.1) : Color.secondary.opacity(0.1))
                .clipShape(Capsule())
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
    let onUpdateImportance: (Int) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                // Header
                HStack {
                    Label(memory.category.rawValue, systemImage: categoryIcon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(categoryColor)
                    
                    Spacer()
                    
                    // Importance stars
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= memory.importance ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(star <= memory.importance ? .yellow : .secondary.opacity(0.3))
                                .onTapGesture {
                                    onUpdateImportance(star)
                                }
                        }
                    }
                    
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
                
                // Footer
                Text("Extracted \(memory.extractedAt.formatted(.relative(presentation: .named)))")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
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
    
    private var categoryIcon: String {
        switch memory.category {
        case .personal: return "person.fill"
        case .emotional: return "heart.fill"
        case .goals: return "target"
        case .relationships: return "person.2.fill"
        case .achievements: return "trophy.fill"
        case .challenges: return "exclamationmark.triangle.fill"
        case .preferences: return "gearshape.fill"
        case .routine: return "clock.fill"
        }
    }
    
    private var categoryColor: Color {
        switch memory.category {
        case .personal: return .blue
        case .emotional: return .pink
        case .goals: return .orange
        case .relationships: return .purple
        case .achievements: return .green
        case .challenges: return .red
        case .preferences: return .indigo
        case .routine: return .cyan
        }
    }
}

// MARK: - Process Entries View

struct ProcessEntriesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var selectedTimeRange: TimeRange = .lastWeek
    
    enum TimeRange: String, CaseIterable {
        case lastWeek = "Last Week"
        case lastMonth = "Last Month"
        case lastThreeMonths = "Last 3 Months"
        case all = "All Entries"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Process Journal Entries")
                    .font(Theme.Typography.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isProcessing)
            }
            .padding()
            
            Divider()
            
            // Content
            VStack(spacing: Theme.largeSpacing) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.primaryAccent)
                    .symbolRenderingMode(.hierarchical)
                
                Text("Extract memories from your journal entries")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 400)
                
                if isProcessing {
                    VStack(spacing: Theme.spacing) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Processing \(processedCount) entries...")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding()
                } else {
                    Button {
                        processEntries()
                    } label: {
                        Label("Extract Memories", systemImage: "brain")
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Theme.Colors.primaryAccent)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
        }
        .frame(width: 500, height: 400)
        .background(Theme.Colors.windowBackground)
    }
    
    private func processEntries() {
        Task {
            isProcessing = true
            
            // Get entries based on time range
            let entries = await getEntriesForTimeRange()
            
            // Process each entry
            for (index, entry) in entries.enumerated() {
                processedCount = index + 1
                await GemiAICoordinator.shared.processJournalEntry(entry)
                
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