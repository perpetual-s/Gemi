//
//  MainWindowView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/29/25.
//

import SwiftUI

/// MainWindowView presents Gemi's spacious coffee shop-inspired interface
/// with generous breathing room and Claude-style elegant organization
struct MainWindowView: View {
    
    // MARK: - Dependencies
    
    @Environment(JournalStore.self) private var journalStore
    
    // MARK: - State
    
    @State private var selectedEntry: JournalEntry?
    @State private var showingNewEntry = false
    @State private var showingChat = false
    @State private var sidebarSelection: SidebarItem = .timeline
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: DesignSystem.Spacing.panelGap) {
                // Left Sidebar (30% - substantial and breathing)
                modernSidebar
                    .frame(width: geometry.size.width * 0.28)
                
                // Right Content Area (70% - spacious content focus)
                floatingContentArea
                    .frame(width: geometry.size.width * 0.72 - DesignSystem.Spacing.panelGap)
            }
            .padding(DesignSystem.Spacing.base)
        }
        .gemiCanvas()
        .sheet(isPresented: $showingNewEntry) {
            ComposeView(entry: .constant(nil))
        }
        .sheet(isPresented: $showingChat) {
            chatPlaceholder
        }
        .onAppear {
            Task {
                await journalStore.refreshEntries()
            }
        }
    }
    
    // MARK: - Spacious Coffee Shop Sidebar
    
    @ViewBuilder
    private var modernSidebar: some View {
        VStack(spacing: DesignSystem.Spacing.sectionSpacing) {
            // Header with breathing room
            sidebarHeader
            
            // Navigation with generous spacing
            sidebarNavigation
            
            Spacer(minLength: DesignSystem.Spacing.large)
            
            // Footer with clear separation
            sidebarFooter
        }
        .padding(DesignSystem.Spacing.panelPadding)
        .gemiSidebarPanel()
    }
    
    @ViewBuilder
    private var sidebarHeader: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // App Icon and Title - substantial and welcoming
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: DesignSystem.Components.iconLarge))
                    .foregroundStyle(DesignSystem.Colors.primary)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.micro) {
                    Text("Gemi")
                        .font(DesignSystem.Typography.title2)
                        .elegantSerifStyle()
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Text("AI Journal")
                        .font(DesignSystem.Typography.footnote)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .diaryTypography()
                }
                
                Spacer()
            }
            
            // Quick Actions - substantial touch targets
            HStack(spacing: DesignSystem.Spacing.small) {
                Button {
                    showingNewEntry = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: DesignSystem.Components.iconMedium))
                        .frame(width: DesignSystem.Components.touchTarget, height: DesignSystem.Components.touchTarget)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                        .fill(DesignSystem.Colors.hover.opacity(0.5))
                )
                .help("Create new journal entry")
                .keyboardShortcut("n", modifiers: .command)
                
                Button {
                    showingChat = true
                } label: {
                    Image(systemName: "message.circle")
                        .font(.system(size: DesignSystem.Components.iconMedium))
                        .frame(width: DesignSystem.Components.touchTarget, height: DesignSystem.Components.touchTarget)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                        .fill(DesignSystem.Colors.hover.opacity(0.5))
                )
                .help("Start conversation with Gemi")
                .keyboardShortcut("t", modifiers: .command)
                
                Spacer()
                
                Button {
                    Task {
                        await journalStore.refreshEntries()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: DesignSystem.Components.iconMedium))
                        .frame(width: DesignSystem.Components.touchTarget, height: DesignSystem.Components.touchTarget)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                        .fill(DesignSystem.Colors.hover.opacity(0.5))
                )
                .help("Refresh entries")
                .disabled(journalStore.isLoading)
            }
        }
    }
    
    @ViewBuilder
    private var sidebarNavigation: some View {
        VStack(spacing: DesignSystem.Spacing.cardSpacing) {
            ForEach(SidebarItem.allCases, id: \.self) { item in
                sidebarNavigationItem(item)
            }
        }
    }
    
    @ViewBuilder
    private func sidebarNavigationItem(_ item: SidebarItem) -> some View {
        Button {
            withAnimation(DesignSystem.Animation.spring) {
                sidebarSelection = item
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: item.icon)
                    .font(.system(size: DesignSystem.Components.iconMedium))
                    .foregroundStyle(sidebarSelection == item ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                    .frame(width: DesignSystem.Components.iconLarge, alignment: .center)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.micro) {
                    Text(item.title)
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(sidebarSelection == item ? .semibold : .medium)
                        .foregroundStyle(sidebarSelection == item ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                        .handwrittenStyle()
                    
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .diaryTypography()
                    }
                }
                
                Spacer()
                
                if sidebarSelection == item {
                    Circle()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .frame(minHeight: DesignSystem.Components.sidebarItemHeight)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                    .fill(sidebarSelection == item ? DesignSystem.Colors.selection : Color.clear)
                    .shadow(
                        color: sidebarSelection == item ? DesignSystem.Colors.shadowLight : Color.clear,
                        radius: sidebarSelection == item ? 4 : 0,
                        x: 0,
                        y: sidebarSelection == item ? 2 : 0
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var sidebarFooter: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Rectangle()
                .fill(DesignSystem.Colors.divider.opacity(0.6))
                .frame(height: 1)
            
            HStack(spacing: DesignSystem.Spacing.medium) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.micro) {
                    Text("\(journalStore.entries.count)")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .handwrittenStyle()
                    
                    Text("entries")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .diaryTypography()
                }
                
                Spacer()
                
                Button {
                    // Settings action
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: DesignSystem.Components.iconMedium))
                        .frame(width: DesignSystem.Components.touchTarget, height: DesignSystem.Components.touchTarget)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                                .fill(DesignSystem.Colors.hover.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .help("Settings")
            }
        }
    }
    
    // MARK: - Spacious Floating Content Area
    
    @ViewBuilder
    private var floatingContentArea: some View {
        ZStack {
            // Background canvas with gentle gradient
            Color.clear
            
            // Main floating panel with generous breathing room on ALL sides
            mainFloatingPanel
                .padding(.all, DesignSystem.Spacing.base)
        }
    }
    
    @ViewBuilder
    private var mainFloatingPanel: some View {
        VStack(spacing: 0) {
            // Panel header with substantial presence
            panelHeader
            
            // Panel content with spacious interior
            panelContent
        }
        .gemiFloatingPanel(cornerRadius: 28, shadowIntensity: 1.4)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
    
    @ViewBuilder
    private var panelHeader: some View {
        HStack(spacing: DesignSystem.Spacing.large) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text(sidebarSelection.title)
                    .font(DesignSystem.Typography.title1)
                    .elegantSerifStyle()
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                if let description = sidebarSelection.description {
                    Text(description)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .diaryTypography()
                }
            }
            
            Spacer()
            
            // Panel actions with substantial presence
            panelHeaderActions
        }
        .padding(.horizontal, DesignSystem.Spacing.panelPadding)
        .padding(.vertical, DesignSystem.Spacing.contentPadding)
        .frame(minHeight: DesignSystem.Components.panelHeaderHeight)
        .background(
            Rectangle()
                .fill(.regularMaterial.opacity(0.8))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignSystem.Colors.divider.opacity(0.4))
                        .frame(height: 1)
                }
        )
    }
    
    @ViewBuilder
    private var panelHeaderActions: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            if sidebarSelection == .timeline {
                Menu {
                    Button("Sort by Date") { }
                    Button("Sort by Length") { }
                    Divider()
                    Button("Export All") { }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: DesignSystem.Components.iconMedium))
                        .frame(width: DesignSystem.Components.touchTarget, height: DesignSystem.Components.touchTarget)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                        .fill(DesignSystem.Colors.hover.opacity(0.5))
                )
            }
            
            if sidebarSelection == .chat {
                Button {
                    // Clear chat
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: DesignSystem.Components.iconMedium))
                        .frame(width: DesignSystem.Components.touchTarget, height: DesignSystem.Components.touchTarget)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                        .fill(DesignSystem.Colors.hover.opacity(0.5))
                )
            }
        }
    }
    
    @ViewBuilder
    private var panelContent: some View {
        Group {
            switch sidebarSelection {
            case .timeline:
                TimelineView(selectedEntry: $selectedEntry)
                    .padding(DesignSystem.Spacing.contentPadding)
                
            case .chat:
                chatPlaceholder
                
            case .memories:
                memoriesPlaceholder
                
            case .insights:
                insightsPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Spacious Coffee Shop Placeholder Views
    
    @ViewBuilder
    private var chatPlaceholder: some View {
        VStack(spacing: DesignSystem.Spacing.huge) {
            Image(systemName: "message.circle.fill")
                .font(.system(size: DesignSystem.Components.iconHuge * 2))
                .foregroundStyle(DesignSystem.Colors.primary)
                .shadow(color: DesignSystem.Colors.shadowLight, radius: 8, x: 0, y: 4)
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("Talk to Gemi")
                    .font(DesignSystem.Typography.display)
                    .elegantSerifStyle()
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Start a conversation with your AI journal companion.\nGemi remembers your past entries and can help you reflect,\nexplore your thoughts, or simply provide a friendly ear.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .relaxedReadingStyle()
                    .frame(maxWidth: 480)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.panelPadding)
    }
    
    @ViewBuilder
    private var memoriesPlaceholder: some View {
        VStack(spacing: DesignSystem.Spacing.huge) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: DesignSystem.Components.iconHuge * 2))
                .foregroundStyle(DesignSystem.Colors.secondary)
                .shadow(color: DesignSystem.Colors.shadowLight, radius: 8, x: 0, y: 4)
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("Memories")
                    .font(DesignSystem.Typography.display)
                    .elegantSerifStyle()
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Manage what Gemi remembers about you.\nReview, edit, or delete the memories that Gemi has formed\nfrom your journal entries and conversations.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .relaxedReadingStyle()
                    .frame(maxWidth: 480)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.panelPadding)
    }
    
    @ViewBuilder
    private var insightsPlaceholder: some View {
        VStack(spacing: DesignSystem.Spacing.huge) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: DesignSystem.Components.iconHuge * 2))
                .foregroundStyle(DesignSystem.Colors.success)
                .shadow(color: DesignSystem.Colors.shadowLight, radius: 8, x: 0, y: 4)
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("Insights")
                    .font(DesignSystem.Typography.display)
                    .elegantSerifStyle()
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Discover patterns in your journaling journey.\nExplore trends in your mood, writing frequency,\nand personal growth over time.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .relaxedReadingStyle()
                    .frame(maxWidth: 480)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.panelPadding)
    }
}

// MARK: - Sidebar Item Model

enum SidebarItem: String, CaseIterable {
    case timeline = "timeline"
    case chat = "chat"
    case memories = "memories"
    case insights = "insights"
    
    var title: String {
        switch self {
        case .timeline: return "Timeline"
        case .chat: return "Chat"
        case .memories: return "Memories"
        case .insights: return "Insights"
        }
    }
    
    var icon: String {
        switch self {
        case .timeline: return "book.pages"
        case .chat: return "message.circle"
        case .memories: return "brain.head.profile"
        case .insights: return "chart.line.uptrend.xyaxis"
        }
    }
    
    var subtitle: String? {
        switch self {
        case .timeline: return "Your journal entries"
        case .chat: return "Talk to Gemi"
        case .memories: return "What Gemi remembers"
        case .insights: return "Discover patterns"
        }
    }
    
    var description: String? {
        switch self {
        case .timeline: return "All your journal entries in chronological order"
        case .chat: return "Have a conversation with your AI companion"
        case .memories: return "Manage what Gemi remembers about your life"
        case .insights: return "Analyze your journaling patterns and growth"
        }
    }
}

// MARK: - Previews

#Preview("Main Window") {
    let store: JournalStore = {
        do {
            return try JournalStore()
        } catch {
            fatalError("Failed to create JournalStore for preview")
        }
    }()
    
    return MainWindowView()
        .environment(store)
        .frame(width: 1200, height: 800)
}