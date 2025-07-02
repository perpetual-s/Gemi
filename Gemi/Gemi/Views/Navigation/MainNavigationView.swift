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
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            SimplifiedSidebar()
                .navigationSplitViewColumnWidth(
                    ideal: navigation.isSidebarCollapsed ? 64 : 240
                )
        } detail: {
            // Main content with toolbar
            VStack(spacing: 0) {
                TopToolbar()
                
                // Content based on selected section
                ZStack {
                    switch navigation.selectedSection {
                    case .today:
                        TodayView()
                    case .entries:
                        EntriesView()
                    case .insights:
                        InsightsView()
                    case .settings:
                        SettingsView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(navigation.selectedSection)
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

struct EntriesView: View {
    @Environment(NavigationModel.self) private var navigation
    @State private var searchText = ""
    @State private var selectedEntry: JournalEntry?
    
    var body: some View {
        VStack(spacing: 0) {
            // Entries header
            HStack {
                Text("All Entries")
                    .font(ModernDesignSystem.Typography.title1)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                // Filter options
                Menu {
                    Button("All Entries") {}
                    Button("This Week") {}
                    Button("This Month") {}
                    Button("This Year") {}
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        .font(ModernDesignSystem.Typography.callout)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(ModernDesignSystem.Spacing.lg)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                TextField("Search entries...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(ModernDesignSystem.Typography.body)
            }
            .padding(ModernDesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                    .fill(ModernDesignSystem.Colors.backgroundTertiary)
            )
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.bottom, ModernDesignSystem.Spacing.md)
            
            Divider()
            
            // Entries list
            ScrollView {
                LazyVStack(spacing: ModernDesignSystem.Spacing.sm) {
                    ForEach(0..<10) { index in
                        TimelineCard(
                            date: Date().addingTimeInterval(TimeInterval(-86400 * index)),
                            title: "Journal Entry \(index + 1)",
                            preview: "This is a preview of the journal entry content. It shows the first few lines of what was written...",
                            mood: [MoodIndicator.Mood.happy, .calm, .focused, .reflective].randomElement(),
                            wordCount: Int.random(in: 100...500),
                            isSelected: false,
                            action: {}
                        )
                    }
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
        }
        .background(ModernDesignSystem.Colors.backgroundPrimary)
    }
}

struct InsightsView: View {
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
                    InsightCard(
                        icon: "brain.head.profile",
                        title: "Emotional Patterns",
                        description: "You've been feeling more positive this week",
                        color: ModernDesignSystem.Colors.moodReflective
                    )
                    
                    InsightCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Writing Consistency",
                        description: "You've maintained a 7-day streak!",
                        color: ModernDesignSystem.Colors.moodEnergetic
                    )
                    
                    InsightCard(
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

struct InsightCard: View {
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