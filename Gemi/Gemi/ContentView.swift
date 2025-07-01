//
//  ContentView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

/// ContentView presents Gemi's stunning floating interface with a modern macOS design
struct ContentView: View {
    
    // MARK: - Accessibility
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - Dependencies
    
    @Environment(JournalStore.self) private var journalStore
    @Environment(PerformanceOptimizer.self) private var performanceOptimizer
    @Environment(AccessibilityManager.self) private var accessibilityManager
    @Environment(KeyboardNavigationState.self) private var keyboardNavigation
    
    // MARK: - State
    
    @State private var selectedEntry: JournalEntry?
    @State private var showingNewEntry = false
    @State private var showingChat = false
    @State private var sidebarSelection: NavigationItem = .timeline
    @FocusState private var focusedField: FocusableField?
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            // Translucent sidebar with vibrancy
            translucntSidebar
                .frame(width: 280)
            
            // Main content area with floating panel
            mainContentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(canvasBackground)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 0) {
                    // Empty space for visual balance
                    Color.clear.frame(width: 280)
                }
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .sheet(isPresented: $showingNewEntry) {
            ComposeView(entry: .constant(nil))
        }
        .overlay(alignment: .bottomTrailing) {
            // Floating action button for chat
            if !showingChat {
                ChatFloatingActionButton {
                    showingChat = true
                    // Haptic feedback on button press
                }
                .padding(32)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .overlay {
            // Chat overlay
            ChatView(isPresented: $showingChat)
        }
        .onAppear {
            Task {
                await journalStore.refreshEntries()
            }
        }
    }
    
    // MARK: - Canvas Background
    
    @ViewBuilder
    private var canvasBackground: some View {
        ZStack {
            // Two-tone background matching sidebar and content
            HStack(spacing: 0) {
                // Left side - matching sidebar color
                Color(red: 0.94, green: 0.93, blue: 0.92)
                    .frame(width: 280)
                
                // Right side - lighter content area
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.96),
                        Color(red: 0.96, green: 0.95, blue: 0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Subtle noise texture overlay
            Rectangle()
                .fill(.regularMaterial)
                .opacity(0.02)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Translucent Sidebar
    
    @ViewBuilder
    private var translucntSidebar: some View {
        ZStack {
            // Vibrancy background
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
            
            VStack(spacing: 0) {
                // App identity section
                appIdentitySection
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 20)
                
                Divider()
                    .opacity(0.3)
                
                // Navigation items
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(NavigationItem.allCases, id: \.self) { item in
                            navigationItem(item)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 20)
                }
                
                Spacer(minLength: 0)
                
                // Bottom section
                bottomSection
                    .padding(20)
            }
        }
    }
    
    @ViewBuilder
    private var appIdentitySection: some View {
        VStack(spacing: 16) {
            // App icon and name
            HStack(spacing: 12) {
                // Beautiful gradient icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.36, green: 0.61, blue: 0.84),
                                    Color(red: 0.48, green: 0.70, blue: 0.90)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gemi")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("AI Journal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Quick action buttons
            HStack(spacing: 8) {
                QuickActionButton(
                    icon: "square.and.pencil",
                    label: "New Entry",
                    color: Color(red: 0.36, green: 0.61, blue: 0.84)
                ) {
                    showingNewEntry = true
                    // Haptic feedback on button press
                }
                .keyboardShortcut("n", modifiers: .command)
                
                QuickActionButton(
                    icon: "message.fill",
                    label: "Chat",
                    color: Color(red: 0.48, green: 0.70, blue: 0.90)
                ) {
                    showingChat = true
                    // Haptic feedback on button press
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
    
    @ViewBuilder
    private func navigationItem(_ item: NavigationItem) -> some View {
        NavigationButton(
            item: item,
            isSelected: sidebarSelection == item
        ) {
            withAnimation(DesignSystem.Animation.encouragingSpring) {
                sidebarSelection = item
            }
            HapticFeedback.selection()
        }
    }
    
    @ViewBuilder
    private var bottomSection: some View {
        VStack(spacing: 16) {
            Divider()
                .opacity(0.3)
            
            // Entry count
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(journalStore.entries.count)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("journal entries")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Settings button
                Button {
                    // Settings action
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Main Content Area
    
    @ViewBuilder
    private var mainContentArea: some View {
        ZStack {
            // Content based on selection
            floatingPanel
                .padding(40)
        }
    }
    
    @ViewBuilder
    private var floatingPanel: some View {
        VStack(spacing: 0) {
            // Panel content
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                
                // Content
                VStack(spacing: 0) {
                    // Header
                    panelHeader
                    
                    Divider()
                        .opacity(0.1)
                    
                    // Main content
                    panelContent
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.08), radius: 48, x: 0, y: 16)
        }
    }
    
    @ViewBuilder
    private var panelHeader: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: sidebarSelection.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.61, blue: 0.84),
                            Color(red: 0.48, green: 0.70, blue: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .animation(.easeInOut(duration: 0.2), value: sidebarSelection)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(sidebarSelection.title)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                    .animation(.easeInOut(duration: 0.2), value: sidebarSelection)
                
                if let subtitle = sidebarSelection.subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: sidebarSelection)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                if sidebarSelection == .timeline {
                    Button {
                        // Search action
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.primary.opacity(0.08))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(Color(red: 0.98, green: 0.98, blue: 0.97))
    }
    
    @ViewBuilder
    private var panelContent: some View {
        ZStack {
            switch sidebarSelection {
            case .timeline:
                TimelineView(selectedEntry: $selectedEntry)
                    .padding(32)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 30)),
                        removal: .opacity.combined(with: .offset(x: -30))
                    ))
            case .chat:
                emptyChatView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 30)),
                        removal: .opacity.combined(with: .offset(x: -30))
                    ))
            case .memories:
                memoriesView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 30)),
                        removal: .opacity.combined(with: .offset(x: -30))
                    ))
            case .insights:
                insightsView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 30)),
                        removal: .opacity.combined(with: .offset(x: -30))
                    ))
            }
        }
        .animation(reduceMotion ? .linear(duration: 0.1) : DesignSystem.Animation.standard, value: sidebarSelection)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var emptyChatView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "message.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.8),
                            Color(red: 0.48, green: 0.70, blue: 0.90).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 12) {
                Text("Start a conversation")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                
                Text("Chat with Gemi about your thoughts and feelings")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
    
    @ViewBuilder
    private var memoriesView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.8),
                            Color(red: 0.48, green: 0.70, blue: 0.90).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 12) {
                Text("Your memories")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                
                Text("Manage what Gemi remembers about your journey")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
    
    @ViewBuilder
    private var insightsView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.8),
                            Color(red: 0.48, green: 0.70, blue: 0.90).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 12) {
                Text("Discover patterns")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                
                Text("See how your thoughts and feelings evolve over time")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - Navigation Item

enum NavigationItem: String, CaseIterable {
    case timeline
    case chat
    case memories
    case insights
    
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
        case .timeline: return "book.pages.fill"
        case .chat: return "message.fill"
        case .memories: return "brain.head.profile"
        case .insights: return "chart.line.uptrend.xyaxis"
        }
    }
    
    var subtitle: String? {
        switch self {
        case .timeline: return "Browse your journal entries"
        case .chat: return "Talk with your AI companion"
        case .memories: return "What Gemi remembers"
        case .insights: return "Analyze your patterns"
        }
    }
}

// MARK: - Components

struct NavigationButton: View {
    let item: NavigationItem
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.8))
                    .frame(width: 24)
                
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.8))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected ? 
                        LinearGradient(
                            colors: [
                                Color(red: 0.36, green: 0.61, blue: 0.84),
                                Color(red: 0.42, green: 0.67, blue: 0.88)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [
                                isHovered ? Color.primary.opacity(0.08) : Color.clear,
                                isHovered ? Color.primary.opacity(0.05) : Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .animation(reduceMotion ? .linear(duration: 0.1) : DesignSystem.Animation.quick, value: isPressed)
            .animation(reduceMotion ? .linear(duration: 0.1) : DesignSystem.Animation.encouragingSpring, value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isHovered ? .white : color)
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isHovered ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isHovered ?
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.primary.opacity(0.05), Color.primary.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .shadow(
                color: isHovered ? color.opacity(0.3) : Color.clear,
                radius: isHovered ? 8 : 0,
                x: 0,
                y: 4
            )
            .animation(reduceMotion ? .linear(duration: 0.1) : DesignSystem.Animation.playfulBounce, value: isHovered)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(isPulsing ? 0 : 0.3), lineWidth: 1.5)
                    .scaleEffect(isPulsing ? 1.1 : 1)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(
                        isPulsing ? DesignSystem.Animation.standard : nil,
                        value: isPulsing
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                isPulsing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPulsing = false
                }
            }
        }
    }
}

// MARK: - Visual Effect View

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

// MARK: - Preview

#Preview {
    let store: JournalStore = {
        do {
            return try JournalStore()
        } catch {
            fatalError("Failed to create JournalStore for preview")
        }
    }()
    
    return ContentView()
        .environment(store)
        .frame(width: 1400, height: 900)
}