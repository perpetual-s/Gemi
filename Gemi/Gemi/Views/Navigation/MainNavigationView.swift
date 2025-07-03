//
//  MainNavigationView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct MainNavigationView: View {
    @State private var navigation = NavigationModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @FocusState private var isSearchFocused: Bool
    @Environment(JournalStore.self) private var journalStore
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            SimplifiedSidebar()
                .environment(navigation)
                .navigationSplitViewColumnWidth(
                    ideal: navigation.isSidebarCollapsed ? 64 : 240
                )
        } detail: {
            // Main content with toolbar
            VStack(spacing: 0) {
                TopToolbar(
                    navigationModel: navigation,
                    isSearchFocused: $isSearchFocused,
                    onNewEntry: {
                        navigation.openNewEntry()
                    }
                )
                
                // Content based on selected section or editor
                if navigation.showingEditor {
                    EnhancedJournalEditor(
                        entry: .constant(navigation.editingEntry),
                        isPresented: .constant(true),
                        onSave: { entry in
                            Task {
                                if navigation.editingEntry == nil {
                                    // New entry
                                    try? await journalStore.addEntry(entry)
                                } else {
                                    // Update existing entry
                                    try? await journalStore.updateEntry(navigation.editingEntry!, content: entry.content)
                                }
                                navigation.closeEditor()
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                } else {
                    ZStack {
                        switch navigation.selectedSection {
                        case .today:
                            TodayView()
                        case .entries:
                            JournalTimelineView()
                        case .insights:
                            InsightsView()
                        case .settings:
                            SettingsView(isPresented: .constant(true))
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(navigation.selectedSection)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .environment(navigation)
        .onAppear {
            setupKeyboardShortcuts()
        }
    }
    
    // MARK: - Keyboard Shortcuts
    
    private func setupKeyboardShortcuts() {
        // Handled by individual navigation items
    }
}

// MARK: - Placeholder Views

struct PlaceholderInsightsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.xl) {
                // Header
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Your Insights")
                        .font(ModernDesignSystem.Typography.title1)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("AI-powered patterns and reflections from your journal")
                        .font(ModernDesignSystem.Typography.callout)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Insights cards
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    PlaceholderInsightCard(
                        icon: "brain.head.profile",
                        title: "Emotional Patterns",
                        description: "You've been feeling more positive this week",
                        color: ModernDesignSystem.Colors.moodReflective
                    )
                    
                    PlaceholderInsightCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Writing Consistency",
                        description: "You've maintained a 7-day streak!",
                        color: ModernDesignSystem.Colors.moodEnergetic
                    )
                    
                    PlaceholderInsightCard(
                        icon: "sparkles",
                        title: "Recurring Themes",
                        description: "Growth, gratitude, and family appear frequently",
                        color: ModernDesignSystem.Colors.moodHappy
                    )
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .frame(maxWidth: ModernDesignSystem.Spacing.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(ModernDesignSystem.Colors.backgroundPrimary)
    }
}

struct PlaceholderInsightCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ModernDesignSystem.Typography.headline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(ModernDesignSystem.Colors.textTertiary)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                .fill(ModernDesignSystem.Colors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

struct MainNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        MainNavigationView()
            .frame(width: 1200, height: 800)
    }
}