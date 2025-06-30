//
//  MainWindowView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/29/25.
//

import SwiftUI

/// MainWindowView presents Gemi's sophisticated floating panel interface
/// with a 35/65 split layout featuring elegant depth and modern design
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
            HStack(spacing: 0) {
                // Left Sidebar (25% - more compact)
                modernSidebar
                    .frame(width: geometry.size.width * 0.25)
                
                // Right Content Area (75% - more space for content)
                floatingContentArea
                    .frame(width: geometry.size.width * 0.75)
            }
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
    
    // MARK: - Modern Sidebar
    
    @ViewBuilder
    private var modernSidebar: some View {
        VStack(spacing: 0) {
            // Header
            sidebarHeader
            
            // Navigation
            sidebarNavigation
            
            Spacer()
            
            // Footer
            sidebarFooter
        }
        .padding(DesignSystem.Spacing.base)
        .gemiSidebarPanel()
        .padding(.trailing, DesignSystem.Spacing.medium)
    }
    
    @ViewBuilder
    private var sidebarHeader: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            // App Icon and Title - more compact
            HStack(spacing: DesignSystem.Spacing.tiny) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.title3)
                    .foregroundStyle(DesignSystem.Colors.primary)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Gemi")
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Text("AI Journal")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                
                Spacer()
            }
            
            // Quick Actions - more compact
            HStack(spacing: DesignSystem.Spacing.tiny) {
                Button {
                    showingNewEntry = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .help("Create new journal entry")
                .keyboardShortcut("n", modifiers: .command)
                
                Button {
                    showingChat = true
                } label: {
                    Image(systemName: "message.circle")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .help("Start conversation with Gemi")
                .keyboardShortcut("t", modifiers: .command)
                
                Spacer()
                
                Button {
                    Task {
                        await journalStore.refreshEntries()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .help("Refresh entries")
                .disabled(journalStore.isLoading)
            }
        }
        .padding(.bottom, DesignSystem.Spacing.medium)
    }
    
    @ViewBuilder
    private var sidebarNavigation: some View {
        VStack(spacing: DesignSystem.Spacing.tiny) {
            ForEach(SidebarItem.allCases, id: \.self) { item in
                sidebarNavigationItem(item)
            }
        }
    }
    
    @ViewBuilder
    private func sidebarNavigationItem(_ item: SidebarItem) -> some View {
        Button {
            withAnimation(DesignSystem.Animation.quick) {
                sidebarSelection = item
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: item.icon)
                    .font(.callout)
                    .foregroundStyle(sidebarSelection == item ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                    .frame(width: 16)
                
                Text(item.title)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(sidebarSelection == item ? .semibold : .medium)
                    .foregroundStyle(sidebarSelection == item ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                
                Spacer()
                
                if sidebarSelection == item {
                    Circle()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.tiny)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                    .fill(sidebarSelection == item ? DesignSystem.Colors.primary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var sidebarFooter: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Divider()
            
            HStack {
                Text("\(journalStore.entries.count) entries")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                
                Spacer()
                
                Button {
                    // Settings action
                } label: {
                    Image(systemName: "gearshape")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .padding(.top, DesignSystem.Spacing.small)
    }
    
    // MARK: - Floating Content Area
    
    @ViewBuilder
    private var floatingContentArea: some View {
        ZStack {
            // Background canvas
            Color.clear
            
            // Main floating panel
            mainFloatingPanel
                .padding(DesignSystem.Spacing.large)
        }
    }
    
    @ViewBuilder
    private var mainFloatingPanel: some View {
        VStack(spacing: 0) {
            // Panel header
            panelHeader
            
            // Panel content
            panelContent
        }
        .gemiFloatingPanel(cornerRadius: 24, shadowIntensity: 1.2)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    @ViewBuilder
    private var panelHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sidebarSelection.title)
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                if let description = sidebarSelection.description {
                    Text(description)
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            // Panel actions
            panelHeaderActions
        }
        .padding(.horizontal, DesignSystem.Spacing.large)
        .padding(.vertical, DesignSystem.Spacing.base)
        .background(
            Rectangle()
                .fill(DesignSystem.Colors.backgroundSecondary.opacity(0.3))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignSystem.Colors.divider.opacity(0.2))
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
                    Label("Options", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
                .gemiSubtleButton()
            }
            
            if sidebarSelection == .chat {
                Button {
                    // Clear chat
                } label: {
                    Label("Clear Chat", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .gemiSubtleButton()
            }
        }
    }
    
    @ViewBuilder
    private var panelContent: some View {
        Group {
            switch sidebarSelection {
            case .timeline:
                TimelineView(selectedEntry: $selectedEntry)
                    .background(Color.clear)
                
            case .chat:
                chatPlaceholder
                    .background(Color.clear)
                
            case .memories:
                memoriesPlaceholder
                    .background(Color.clear)
                
            case .insights:
                insightsPlaceholder
                    .background(Color.clear)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Placeholder Views
    
    @ViewBuilder
    private var chatPlaceholder: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Image(systemName: "message.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.primary)
            
            Text("Talk to Gemi")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Text("Start a conversation with your AI journal companion")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private var memoriesPlaceholder: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.secondary)
            
            Text("Memories")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Text("Manage what Gemi remembers about you")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private var insightsPlaceholder: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.success)
            
            Text("Insights")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Text("Discover patterns in your journaling journey")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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