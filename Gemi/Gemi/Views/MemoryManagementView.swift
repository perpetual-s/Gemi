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
    @State private var memories: [MemoryDisplayItem] = []
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var memoryToDelete: MemoryDisplayItem?
    
    var filteredMemories: [MemoryDisplayItem] {
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
            
            // Content
            if memories.isEmpty {
                emptyStateView
            } else {
                memoryListView
            }
        }
        .frame(width: 800, height: 600)
        .background(DesignSystem.Colors.backgroundPrimary)
        .onAppear {
            loadMemories()
        }
        .alert("Delete Memory", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let memory = memoryToDelete {
                    deleteMemory(memory)
                }
            }
        } message: {
            Text("Are you sure you want to delete this memory? This action cannot be undone.")
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
                Text("\(filteredMemories.count) memories")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                Spacer()
                
                Button(action: clearAllMemories) {
                    Label("Clear All", systemImage: "trash")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
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
                        }
                    }
                }
                .padding(DesignSystem.Spacing.large)
            }
        }
    }
    
    // MARK: - Methods
    
    private func loadMemories() {
        // Sample memories for now
        memories = [
            MemoryDisplayItem(id: UUID(), content: "Enjoys morning journaling sessions with coffee", category: .preference, createdAt: Date().addingTimeInterval(-86400 * 7)),
            MemoryDisplayItem(id: UUID(), content: "Working on improving work-life balance", category: .goal, createdAt: Date().addingTimeInterval(-86400 * 3)),
            MemoryDisplayItem(id: UUID(), content: "Finds writing therapeutic during stressful times", category: .insight, createdAt: Date().addingTimeInterval(-86400 * 1)),
            MemoryDisplayItem(id: UUID(), content: "Prefers bullet journaling format for daily entries", category: .preference, createdAt: Date())
        ]
    }
    
    private func deleteMemory(_ memory: MemoryDisplayItem) {
        withAnimation(DesignSystem.Animation.standard) {
            memories.removeAll { $0.id == memory.id }
        }
    }
    
    private func clearAllMemories() {
        // Show confirmation alert
        memories.removeAll()
    }
}

// MARK: - Memory Model

struct MemoryDisplayItem: Identifiable {
    let id: UUID
    let content: String
    let category: MemoryCategory
    let createdAt: Date
}

enum MemoryCategory {
    case preference
    case goal
    case insight
    case fact
    
    var icon: String {
        switch self {
        case .preference: return "heart.fill"
        case .goal: return "target"
        case .insight: return "lightbulb.fill"
        case .fact: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .preference: return .pink
        case .goal: return .orange
        case .insight: return .purple
        case .fact: return .blue
        }
    }
}

// MARK: - Memory Row

struct MemoryRow: View {
    let memory: MemoryDisplayItem
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            // Category icon
            Image(systemName: memory.category.icon)
                .font(.system(size: 16))
                .foregroundStyle(memory.category.color)
                .frame(width: 24, height: 24)
            
            // Content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                Text(memory.content)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text(memory.createdAt, style: .relative)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            
            Spacer()
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
                    .opacity(isHovered ? 1 : 0)
            }
            .buttonStyle(.plain)
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
}

// MARK: - Preview

#Preview {
    MemoryManagementView()
}