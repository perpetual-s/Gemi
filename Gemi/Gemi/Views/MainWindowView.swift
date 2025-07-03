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
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(PerformanceOptimizer.self) private var performanceOptimizer
    @Environment(AccessibilityManager.self) private var accessibilityManager
    @Environment(KeyboardNavigationState.self) private var keyboardNavigation
    
    // MARK: - State
    
    @State private var selectedEntry: JournalEntry?
    @State private var showingChat = false
    @State private var showingSettings = false
    @State private var sidebarSelection: SidebarItem = .timeline
    @State private var hasShownOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @FocusState private var focusedField: FocusableField?
    @State private var isComposingNewEntry = false
    @State private var chatViewModel = ChatViewModel(ollamaService: OllamaService())
    @State private var sortOrder: SortOrder = .dateDescending
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - (DesignSystem.Spacing.base * 2) // Account for container padding
            let sidebarWidth = availableWidth * 0.3
            let contentWidth = availableWidth * 0.7 - DesignSystem.Spacing.panelGap
            
            HStack(spacing: DesignSystem.Spacing.panelGap) {
                // Left Sidebar (30% - substantial and breathing)
                modernSidebar
                    .frame(width: sidebarWidth)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(AccessibilityLabels.timelineTitle)
                
                // Right Content Area (70% - spacious content focus with proper breathing room)
                floatingContentArea
                    .frame(width: contentWidth)
                    .optimizedAnimation()
            }
            .padding(DesignSystem.Spacing.base)
        }
        .gemiCanvas()
        .sheet(isPresented: $showingChat) {
            ChatView(isPresented: $showingChat)
        }
        .onAppear {
            Task {
                await journalStore.refreshEntries()
            }
        }
        .sheet(isPresented: .constant(!onboardingState.hasCompletedOnboarding)) {
            OnboardingView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(isPresented: $showingSettings)
        }
        .focusedValue(\.selectedEntry, selectedEntry)
        .focusedValue(\.showSettings, $showingSettings)
        .focusedValue(\.showChat, $showingChat)
        .onKeyPress(.escape) {
            if isComposingNewEntry {
                withAnimation(DesignSystem.Animation.cozySettle) {
                    isComposingNewEntry = false
                }
                return .handled
            }
            return .ignored
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
                        .font(ModernDesignSystem.Typography.title2)
                        .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextPrimary)
                    
                    Text("AI Journal")
                        .font(ModernDesignSystem.Typography.footnote)
                        .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextTertiary)
                }
                
                Spacer()
            }
            
            // Quick Actions - substantial touch targets with encouraging interactions
            HStack(spacing: DesignSystem.Spacing.small) {
                EncouragingActionButton(
                    icon: "square.and.pencil",
                    help: "Create new journal entry",
                    isLoading: false
                ) {
                    isComposingNewEntry = true
                    sidebarSelection = .timeline
                }
                .keyboardShortcut("n", modifiers: .command)
                .coachMark(
                    .firstEntry,
                    title: "Start Your First Entry",
                    message: "Click here to write your first journal entry. Gemi will help you reflect on your thoughts."
                )
                
                EncouragingActionButton(
                    icon: "message.circle",
                    help: "Start conversation with Gemi",
                    isLoading: false
                ) {
                    showingChat = true
                }
                .keyboardShortcut("t", modifiers: .command)
                
                Spacer()
                
                EncouragingActionButton(
                    icon: "arrow.clockwise",
                    help: "Refresh entries",
                    isLoading: journalStore.isLoading,
                    isRotating: journalStore.isLoading
                ) {
                    Task {
                        await journalStore.refreshEntries()
                    }
                }
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
        @State var isHovered = false
        
        Button {
            withAnimation(DesignSystem.Animation.cozySettle) {
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
                        .frame(width: isHovered ? 10 : 8, height: isHovered ? 10 : 8)
                        .scaleEffect(sidebarSelection == item ? 1.0 : 0.8)
                        .animation(DesignSystem.Animation.playfulBounce, value: sidebarSelection == item)
                        .animation(DesignSystem.Animation.supportiveEmphasis, value: isHovered)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .frame(minHeight: DesignSystem.Components.sidebarItemHeight)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                    .fill(
                        sidebarSelection == item ? DesignSystem.Colors.selection : 
                        isHovered ? DesignSystem.Colors.hover : Color.clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                            .stroke(
                                DesignSystem.Colors.primary.opacity(
                                    sidebarSelection == item ? 0.3 : 
                                    isHovered ? 0.2 : 0.0
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: sidebarSelection == item ? DesignSystem.Colors.shadowLight : 
                               isHovered ? DesignSystem.Colors.shadowWhisper : Color.clear,
                        radius: sidebarSelection == item ? 6 : isHovered ? 3 : 0,
                        x: 0,
                        y: sidebarSelection == item ? 3 : isHovered ? 1 : 0
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(DesignSystem.Animation.encouragingSpring, value: sidebarSelection == item)
            .animation(DesignSystem.Animation.gentleFloat, value: isHovered)
            .onHover { hovering in
                withAnimation(DesignSystem.Animation.writingFlow) {
                    isHovered = hovering
                }
            }
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
                    showingSettings = true
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
        // Main floating panel with generous breathing room on ALL sides
        mainFloatingPanel
            .padding(.all, DesignSystem.Spacing.base)
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
                Text(isComposingNewEntry ? "New Entry" : sidebarSelection.title)
                    .font(ModernDesignSystem.Typography.title1)
                    .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextPrimary)
                
                if let description = isComposingNewEntry ? "Share your thoughts in this private, safe space" : sidebarSelection.description {
                    Text(description)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextSecondary)
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
                    Button("Sort by Date (Newest First)") { 
                        sortEntries(by: .dateDescending)
                    }
                    Button("Sort by Date (Oldest First)") { 
                        sortEntries(by: .dateAscending)
                    }
                    Button("Sort by Length (Longest First)") { 
                        sortEntries(by: .lengthDescending)
                    }
                    Button("Sort by Length (Shortest First)") { 
                        sortEntries(by: .lengthAscending)
                    }
                    Divider()
                    Button("Export All Entries...") { 
                        exportAllEntries()
                    }
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
                    chatViewModel.clearChat()
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
            if isComposingNewEntry {
                FloatingComposeView(entry: .constant(nil), onSave: {
                    // On save callback
                    withAnimation(DesignSystem.Animation.cozySettle) {
                        isComposingNewEntry = false
                    }
                    Task {
                        await journalStore.refreshEntries()
                    }
                }, onCancel: {
                    // On cancel callback
                    withAnimation(DesignSystem.Animation.cozySettle) {
                        isComposingNewEntry = false
                    }
                })
                .padding(DesignSystem.Spacing.contentPadding)
            } else {
                switch sidebarSelection {
                case .timeline:
                    TimelineView(selectedEntry: $selectedEntry) {
                        withAnimation(DesignSystem.Animation.cozySettle) {
                            isComposingNewEntry = true
                        }
                    }
                    .padding(DesignSystem.Spacing.contentPadding)
                    
                case .chat:
                    ChatView(isPresented: .constant(true))
                        .environment(chatViewModel)
                    
                case .memories:
                    memoriesPlaceholder
                    
                case .insights:
                    insightsPlaceholder
                    
                case .search:
                    searchPlaceholder
                    
                case .export:
                    exportPlaceholder
                    
                case .help:
                    HelpView()
                        .padding(DesignSystem.Spacing.contentPadding)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Spacious Coffee Shop Placeholder Views
    
    @ViewBuilder
    private var chatPlaceholder: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: DesignSystem.Spacing.extraLarge)
                
                // Warm conversation illustration
                inspiringChatIllustration
                
                Spacer(minLength: DesignSystem.Spacing.large)
                
                // Inviting chat content
                inspiringChatContent
                
                Spacer(minLength: DesignSystem.Spacing.extraLarge)
            }
            .padding(.horizontal, DesignSystem.Spacing.panelPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.backgroundPrimary,
                    DesignSystem.Colors.primary.opacity(0.02),
                    DesignSystem.Colors.backgroundPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    @ViewBuilder
    private var inspiringChatIllustration: some View {
        ZStack {
            // Warm conversation bubbles
            VStack(spacing: 16) {
                // Gemi's message bubble (left)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(DesignSystem.Colors.primary)
                                .frame(width: 8, height: 8)
                                .scaleEffect(chatPulse ? 1.3 : 1.0)
                                .animation(DesignSystem.Animation.heartbeat, value: chatPulse)
                            
                            Text("Hello! I'm here to listen...")
                                .font(DesignSystem.Typography.caption1)
                                .handwrittenStyle()
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(DesignSystem.Colors.primary.opacity(0.1))
                        )
                    }
                    Spacer()
                }
                
                // Your message bubble (right)
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("I'd love to share my thoughts")
                            .font(DesignSystem.Typography.caption1)
                            .handwrittenStyle()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(DesignSystem.Colors.primary.opacity(0.8))
                            )
                    }
                }
                .opacity(0.7)
            }
            .frame(maxWidth: 280)
            
            // Floating hearts for warmth
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Colors.primary.opacity(0.3))
                    .offset(
                        x: CGFloat(index - 1) * 60,
                        y: -40 + CGFloat(index) * 10
                    )
                    .scaleEffect(heartFloat ? 1.2 : 0.8)
                    .opacity(heartFloat ? 0.8 : 0.3)
                    .animation(
                        DesignSystem.Animation.breathing
                            .delay(Double(index) * 0.3),
                        value: heartFloat
                    )
            }
        }
        .onAppear {
            withAnimation {
                chatPulse = true
                heartFloat = true
            }
        }
    }
    
    @ViewBuilder
    private var inspiringChatContent: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            // Warm headline
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("A friend who truly listens")
                    .font(ModernDesignSystem.Typography.display)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                ModernDesignSystem.Colors.primary,
                                ModernDesignSystem.Colors.primary.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .multilineTextAlignment(.center)
                
                Text("No judgments, just understanding")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Encouraging description
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("Imagine having coffee with the most understanding friend—someone who remembers every story you've shared and genuinely cares about your journey.")
                    .font(DesignSystem.Typography.body)
                    .relaxedReadingStyle()
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                
                Text("Gemi knows your entries, celebrates your growth, and offers gentle insights whenever you need them. Your conversations stay between you two, always.")
                    .font(DesignSystem.Typography.callout)
                    .diaryTypography()
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 450)
            }
            
            // Conversation starters
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("✨ Try saying:")
                    .font(DesignSystem.Typography.caption1)
                    .handwrittenStyle()
                    .foregroundStyle(DesignSystem.Colors.primary.opacity(0.8))
                
                VStack(spacing: DesignSystem.Spacing.tiny) {
                    Text("\"How have I been feeling this week?\"")
                        .font(DesignSystem.Typography.caption1)
                        .italic()
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    
                    Text("\"Help me reflect on my recent experiences\"")
                        .font(DesignSystem.Typography.caption1)
                        .italic()
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    
                    Text("\"What patterns do you notice in my writing?\"")
                        .font(DesignSystem.Typography.caption1)
                        .italic()
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
    }
    
    // Animation state for chat
    @State private var chatPulse = false
    @State private var heartFloat = false
    
    @ViewBuilder
    private var memoriesPlaceholder: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: DesignSystem.Spacing.extraLarge)
                
                // Memory constellation illustration
                inspiringMemoryIllustration
                
                Spacer(minLength: DesignSystem.Spacing.large)
                
                // Memory content
                inspiringMemoryContent
                
                Spacer(minLength: DesignSystem.Spacing.extraLarge)
            }
            .padding(.horizontal, DesignSystem.Spacing.panelPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.backgroundPrimary,
                    DesignSystem.Colors.secondary.opacity(0.02),
                    DesignSystem.Colors.backgroundPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    @ViewBuilder
    private var inspiringMemoryIllustration: some View {
        ZStack {
            // Memory constellation
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(DesignSystem.Colors.secondary.opacity(0.6))
                    .frame(width: CGFloat(8 + index * 2), height: CGFloat(8 + index * 2))
                    .offset(
                        x: cos(Double(index) * .pi / 3) * 60,
                        y: sin(Double(index) * .pi / 3) * 60
                    )
                    .scaleEffect(memoryPulse ? 1.2 : 0.8)
                    .opacity(memoryPulse ? 0.8 : 0.4)
                    .animation(
                        DesignSystem.Animation.breathing
                            .delay(Double(index) * 0.2),
                        value: memoryPulse
                    )
            }
            
            // Connecting lines between memories
            ForEach(0..<6, id: \.self) { index in
                Path { path in
                    let center = CGPoint.zero
                    let point = CGPoint(
                        x: cos(Double(index) * .pi / 3) * 60,
                        y: sin(Double(index) * .pi / 3) * 60
                    )
                    path.move(to: center)
                    path.addLine(to: point)
                }
                .stroke(
                    DesignSystem.Colors.secondary.opacity(0.3),
                    lineWidth: 1
                )
                .opacity(memoryPulse ? 0.6 : 0.2)
                .animation(
                    DesignSystem.Animation.breathing
                        .delay(Double(index) * 0.1),
                    value: memoryPulse
                )
            }
            
            // Central memory node
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            DesignSystem.Colors.secondary,
                            DesignSystem.Colors.secondary.opacity(0.7)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 15
                    )
                )
                .frame(width: 30, height: 30)
                .scaleEffect(memoryPulse ? 1.3 : 1.0)
                .animation(DesignSystem.Animation.heartbeat, value: memoryPulse)
        }
        .onAppear {
            withAnimation {
                memoryPulse = true
            }
        }
    }
    
    @ViewBuilder
    private var inspiringMemoryContent: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            // Warm headline
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("Your story, remembered")
                    .font(DesignSystem.Typography.display)
                    .elegantSerifStyle()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.secondary,
                                DesignSystem.Colors.secondary.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .multilineTextAlignment(.center)
                
                Text("Cherished moments, safely kept")
                    .font(DesignSystem.Typography.title3)
                    .handwrittenStyle()
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Encouraging description
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("Like treasured photographs in a family album, Gemi carefully preserves the moments that matter most to you.")
                    .font(DesignSystem.Typography.body)
                    .relaxedReadingStyle()
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                
                Text("These memories help Gemi understand your journey, celebrate your growth, and offer thoughtful reflections. You're always in control—view, cherish, or let go of memories as you choose.")
                    .font(DesignSystem.Typography.callout)
                    .diaryTypography()
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 450)
            }
            
            // Memory examples
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("🧠 Gemi might remember:")
                    .font(DesignSystem.Typography.caption1)
                    .handwrittenStyle()
                    .foregroundStyle(DesignSystem.Colors.secondary.opacity(0.8))
                
                VStack(spacing: DesignSystem.Spacing.tiny) {
                    Text("\"Your excitement about starting a new project\"")
                        .font(DesignSystem.Typography.caption1)
                        .italic()
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    
                    Text("\"That peaceful morning walk you described\"")
                        .font(DesignSystem.Typography.caption1)
                        .italic()
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    
                    Text("\"Your reflections on personal growth\"")
                        .font(DesignSystem.Typography.caption1)
                        .italic()
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
    }
    
    // Animation state for memories
    @State private var memoryPulse = false
    
    @ViewBuilder
    private var insightsPlaceholder: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: DesignSystem.Spacing.extraLarge)
                
                // Growth tree illustration
                inspiringInsightsIllustration
                
                Spacer(minLength: DesignSystem.Spacing.large)
                
                // Insights content
                inspiringInsightsContent
                
                Spacer(minLength: DesignSystem.Spacing.extraLarge)
            }
            .padding(.horizontal, DesignSystem.Spacing.panelPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.backgroundPrimary,
                    DesignSystem.Colors.success.opacity(0.02),
                    DesignSystem.Colors.backgroundPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    @ViewBuilder
    private var inspiringInsightsIllustration: some View {
        ZStack {
            // Growth tree visualization
            VStack(spacing: 0) {
                // Tree crown (insights)
                ZStack {
                    // Leaves/insights floating
                    ForEach(0..<8, id: \.self) { index in
                        Circle()
                            .fill(DesignSystem.Colors.success.opacity(0.7))
                            .frame(width: CGFloat(6 + index % 3 * 2), height: CGFloat(6 + index % 3 * 2))
                            .offset(
                                x: cos(Double(index) * .pi / 4) * Double(30 + index % 2 * 15),
                                y: sin(Double(index) * .pi / 4) * Double(20 + index % 3 * 10)
                            )
                            .scaleEffect(insightGrow ? 1.2 : 0.8)
                            .opacity(insightGrow ? 0.8 : 0.5)
                            .animation(
                                DesignSystem.Animation.breathing
                                    .delay(Double(index) * 0.15),
                                value: insightGrow
                            )
                    }
                    
                    // Central growth burst
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    DesignSystem.Colors.success.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(insightGrow ? 1.3 : 1.0)
                        .animation(DesignSystem.Animation.breathing, value: insightGrow)
                }
                .frame(height: 80)
                
                // Tree trunk (your entries)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.6, green: 0.4, blue: 0.3),
                                Color(red: 0.7, green: 0.5, blue: 0.4)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 8, height: 60)
                    .scaleEffect(x: 1.0, y: insightGrow ? 1.1 : 1.0)
                    .animation(DesignSystem.Animation.encouragingSpring, value: insightGrow)
                
                // Roots (foundation)
                ZStack {
                    ForEach(0..<4, id: \.self) { index in
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addCurve(
                                to: CGPoint(
                                    x: Double(index - 2) * 15,
                                    y: 20
                                ),
                                control1: CGPoint(x: 0, y: 10),
                                control2: CGPoint(
                                    x: Double(index - 2) * 8,
                                    y: 15
                                )
                            )
                        }
                        .stroke(
                            Color(red: 0.5, green: 0.3, blue: 0.2).opacity(0.6),
                            lineWidth: 2
                        )
                        .opacity(insightGrow ? 0.8 : 0.5)
                        .animation(
                            DesignSystem.Animation.cozySettle
                                .delay(Double(index) * 0.1),
                            value: insightGrow
                        )
                    }
                }
                .frame(height: 25)
            }
        }
        .onAppear {
            withAnimation {
                insightGrow = true
            }
        }
    }
    
    @ViewBuilder
    private var inspiringInsightsContent: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            // Warm headline
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("Watch yourself flourish")
                    .font(ModernDesignSystem.Typography.display)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                ModernDesignSystem.Colors.success,
                                ModernDesignSystem.Colors.success.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .multilineTextAlignment(.center)
                
                Text("Growth becomes visible over time")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Encouraging description
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("Like watching a garden bloom, your writing reveals beautiful patterns of growth, reflection, and self-discovery.")
                    .font(DesignSystem.Typography.body)
                    .relaxedReadingStyle()
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                
                Text("See how your thoughts evolve, celebrate your writing journey, and discover the unique rhythms of your inner world. Every entry is a seed of wisdom.")
                    .font(DesignSystem.Typography.callout)
                    .diaryTypography()
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 450)
            }
            
            // Growth examples
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("🌱 You might discover:")
                    .font(DesignSystem.Typography.caption1)
                    .handwrittenStyle()
                    .foregroundStyle(DesignSystem.Colors.success.opacity(0.8))
                
                VStack(spacing: DesignSystem.Spacing.tiny) {
                    Text("\"Your writing flows best in the morning\"")
                        .font(DesignSystem.Typography.caption1)
                        .italic()
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    
                    Text("\"Gratitude appears more in recent entries\"")
                        .font(DesignSystem.Typography.caption1)
                        .italic()
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    
                    Text("\"Your confidence has grown beautifully\"")
                        .font(DesignSystem.Typography.caption1)
                        .italic()
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
    }
    
    // Animation state for insights
    @State private var insightGrow = false
    
    // MARK: - Search Placeholder
    
    @ViewBuilder
    private var searchPlaceholder: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                Spacer(minLength: DesignSystem.Spacing.extraLarge)
                
                // Search illustration
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(DesignSystem.Colors.primary.opacity(0.3))
                
                // Search content
                VStack(spacing: DesignSystem.Spacing.large) {
                    Text("Search Everything")
                        .font(ModernDesignSystem.Typography.display)
                        .foregroundStyle(ModernDesignSystem.Colors.primary)
                    
                    Text("Find entries, memories, and insights instantly")
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextSecondary)
                    
                    // Search bar placeholder
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Text("Search your journal...")
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                            .fill(DesignSystem.Colors.backgroundSecondary)
                    )
                    .frame(maxWidth: 500)
                    
                    Text("Coming soon: Full-text search across all your entries")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                
                Spacer(minLength: DesignSystem.Spacing.extraLarge)
            }
            .padding(.horizontal, DesignSystem.Spacing.panelPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Export Placeholder
    
    @ViewBuilder
    private var exportPlaceholder: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                Spacer(minLength: DesignSystem.Spacing.extraLarge)
                
                // Export illustration
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(DesignSystem.Colors.primary.opacity(0.3))
                
                // Export content
                VStack(spacing: DesignSystem.Spacing.large) {
                    Text("Export Your Journal")
                        .font(ModernDesignSystem.Typography.display)
                        .foregroundStyle(ModernDesignSystem.Colors.primary)
                    
                    Text("Save your entries in various formats")
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextSecondary)
                    
                    // Export options
                    VStack(spacing: DesignSystem.Spacing.medium) {
                        ExportOptionRow(icon: "doc.text", title: "Markdown", description: "Perfect for developers")
                        ExportOptionRow(icon: "doc.plaintext", title: "Plain Text", description: "Universal format")
                        ExportOptionRow(icon: "doc.richtext", title: "PDF", description: "Print-ready format")
                        ExportOptionRow(icon: "archivebox", title: "Full Backup", description: "Complete encrypted backup")
                    }
                    .frame(maxWidth: 500)
                    
                    Text("Export individual entries from the context menu")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                
                Spacer(minLength: DesignSystem.Spacing.extraLarge)
            }
            .padding(.horizontal, DesignSystem.Spacing.panelPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Types
    
    enum SortOrder {
        case dateAscending
        case dateDescending
        case lengthAscending
        case lengthDescending
    }
    
    // MARK: - Export Functionality
    
    private func exportAllEntries() {
        Task {
            do {
                // Create export content
                let entries = journalStore.entries.sorted { entry1, entry2 in
                    switch sortOrder {
                    case .dateAscending:
                        return entry1.date < entry2.date
                    case .dateDescending:
                        return entry1.date > entry2.date
                    case .lengthAscending:
                        return entry1.content.count < entry2.content.count
                    case .lengthDescending:
                        return entry1.content.count > entry2.content.count
                    }
                }
                
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                formatter.timeStyle = .short
                
                var exportContent = "# Gemi Journal Export\n\n"
                exportContent += "Exported on: \(formatter.string(from: Date()))\n\n"
                exportContent += "Total Entries: \(entries.count)\n\n"
                exportContent += "---\n\n"
                
                for entry in entries {
                    exportContent += "## \(formatter.string(from: entry.date))\n\n"
                    if !entry.title.isEmpty {
                        exportContent += "**\(entry.title)**\n\n"
                    }
                    exportContent += entry.content
                    exportContent += "\n\n---\n\n"
                }
                
                // Save to file
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.plainText]
                panel.nameFieldStringValue = "Gemi_Journal_Export_\(Date().ISO8601Format()).txt"
                panel.title = "Export Journal Entries"
                panel.message = "Choose where to save your journal export"
                
                let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
                if response == .OK, let url = panel.url {
                    try exportContent.write(to: url, atomically: true, encoding: .utf8)
                    HapticFeedback.success()
                }
            } catch {
                print("Export failed: \(error)")
                HapticFeedback.error()
            }
        }
    }
}

// MARK: - Sidebar Item Model

enum SidebarItem: String, CaseIterable {
    case timeline = "timeline"
    case chat = "chat"
    case memories = "memories"
    case insights = "insights"
    case search = "search"
    case export = "export"
    case help = "help"
    
    var title: String {
        switch self {
        case .timeline: return "Timeline"
        case .chat: return "Chat with Gemi"
        case .memories: return "Memories"
        case .insights: return "Insights"
        case .search: return "Search"
        case .export: return "Export"
        case .help: return "Help"
        }
    }
    
    var icon: String {
        switch self {
        case .timeline: return "book.pages"
        case .chat: return "message.circle"
        case .memories: return "brain.head.profile"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .search: return "magnifyingglass"
        case .export: return "square.and.arrow.up"
        case .help: return "questionmark.circle"
        }
    }
    
    var subtitle: String? {
        switch self {
        case .timeline: return "Your journal entries"
        case .chat: return "Talk to Gemi"
        case .memories: return "What Gemi remembers"
        case .insights: return "Discover patterns"
        case .search: return "Find anything"
        case .export: return "Save your journal"
        case .help: return "Get assistance"
        }
    }
    
    var description: String? {
        switch self {
        case .timeline: return "All your journal entries in chronological order"
        case .chat: return "Have a conversation with your AI companion"
        case .memories: return "Manage what Gemi remembers about your life"
        case .insights: return "Analyze your journaling patterns and growth"
        case .search: return "Search through your entries, memories, and insights"
        case .export: return "Export your journal in various formats"
        case .help: return "Get help using Gemi and learn about features"
        }
    }
    
    // MARK: - Methods
    
    private func showCoachMarksIfNeeded() {
        // Coach marks are handled by the OnboardingState
        // They will show automatically based on user progress
    }
}

// MARK: - Supporting Views

struct ExportOptionRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(DesignSystem.Colors.primary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .padding(DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                .fill(DesignSystem.Colors.backgroundSecondary)
        )
    }
}

// MARK: - Encouraging Action Button

/// A delightful action button that encourages interaction with warm animations
private struct EncouragingActionButton: View {
    let icon: String
    let help: String
    let isLoading: Bool
    let isRotating: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var rotationAngle = 0.0
    @State private var pulseScale = 1.0
    
    init(
        icon: String, 
        help: String, 
        isLoading: Bool = false, 
        isRotating: Bool = false, 
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.help = help
        self.isLoading = isLoading
        self.isRotating = isRotating
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Components.iconMedium))
                .foregroundStyle(
                    isHovered ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary
                )
                .frame(width: DesignSystem.Components.touchTarget, height: DesignSystem.Components.touchTarget)
                .background(
                    ZStack {
                        // Base background with encouraging warmth
                        RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                            .fill(DesignSystem.Colors.hover.opacity(isHovered ? 0.8 : 0.3))
                        
                        // Gentle glow on hover
                        if isHovered {
                            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                                .stroke(
                                    DesignSystem.Colors.primary.opacity(0.4),
                                    lineWidth: 1.5
                                )
                        }
                        
                        // Encouraging pulse for important actions
                        if icon == "square.and.pencil" {
                            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                                .stroke(
                                    DesignSystem.Colors.primary.opacity(0.2),
                                    lineWidth: 2
                                )
                                .scaleEffect(pulseScale)
                                .onAppear {
                                    withAnimation(DesignSystem.Animation.breathing) {
                                        pulseScale = 1.1
                                    }
                                }
                        }
                    }
                )
                .rotationEffect(.degrees(isRotating ? rotationAngle : 0))
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .brightness(isHovered ? 0.1 : 0)
        }
        .buttonStyle(.borderless)
        .animation(DesignSystem.Animation.supportiveEmphasis, value: isHovered)
        .animation(DesignSystem.Animation.writingFlow, value: isLoading)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.gentleFloat) {
                isHovered = hovering
            }
        }
        .onChange(of: isRotating) { _, rotating in
            if rotating {
                withAnimation(DesignSystem.Animation.standard.repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            } else {
                withAnimation(DesignSystem.Animation.cozySettle) {
                    rotationAngle = 0
                }
            }
        }
        .help(help)
    }
}

// MARK: - Helper Methods

extension MainWindowView {
    private func sortEntries(by order: SortOrder) {
        sortOrder = order
        
        withAnimation(DesignSystem.Animation.spring) {
            switch order {
            case .dateDescending:
                journalStore.entries.sort { $0.date > $1.date }
            case .dateAscending:
                journalStore.entries.sort { $0.date < $1.date }
            case .lengthDescending:
                journalStore.entries.sort { $0.content.count > $1.content.count }
            case .lengthAscending:
                journalStore.entries.sort { $0.content.count < $1.content.count }
            }
        }
        
        HapticFeedback.selection()
    }
    
}

// MARK: - Supporting Types

enum SortOrder {
    case dateDescending
    case dateAscending
    case lengthDescending
    case lengthAscending
}

// MARK: - Previews

#Preview("Main Window") {
    // For preview, we'll use a mock store if initialization fails
    let store = (try? JournalStore()) ?? JournalStore.preview
    
    return MainWindowView()
        .environment(store)
        .frame(width: 1200, height: 800)
}