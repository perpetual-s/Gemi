//
//  ModernComponents.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

// MARK: - Navigation Components

/// Modern navigation bar with glass morphism
struct ModernNavigationBar: View {
    let title: String
    let leadingAction: (() -> Void)?
    let trailingAction: (() -> Void)?
    let leadingIcon: String?
    let trailingIcon: String?
    
    @Environment(\.colorScheme) var colorScheme
    
    init(
        title: String,
        leadingIcon: String? = nil,
        leadingAction: (() -> Void)? = nil,
        trailingIcon: String? = nil,
        trailingAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.leadingIcon = leadingIcon
        self.leadingAction = leadingAction
        self.trailingIcon = trailingIcon
        self.trailingAction = trailingAction
    }
    
    var body: some View {
        HStack {
            if let leadingIcon = leadingIcon, let leadingAction = leadingAction {
                Button(action: leadingAction) {
                    Image(systemName: leadingIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            Text(title)
                .font(ModernDesignSystem.Typography.headline)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Spacer()
            
            if let trailingIcon = trailingIcon, let trailingAction = trailingAction {
                Button(action: trailingAction) {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .frame(height: ModernDesignSystem.Components.navBarHeight)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(ModernDesignSystem.Colors.divider)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - List Components

/// Modern list item with hover effects
struct ModernListItem<Content: View>: View {
    let content: () -> Content
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                .padding(.vertical, ModernDesignSystem.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                        .fill(
                            isPressed ? ModernDesignSystem.Colors.primary.opacity(0.1) :
                            isHovered ? ModernDesignSystem.Colors.backgroundTertiary :
                            Color.clear
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(ModernDesignSystem.Animation.hover) {
                isHovered = hovering
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(ModernDesignSystem.Animation.spring, value: isPressed)
    }
}

// MARK: - Sidebar Components

/// Modern sidebar with sections
struct ModernSidebar<Content: View>: View {
    let content: () -> Content
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(width: ModernDesignSystem.Spacing.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(
            Rectangle()
                .fill(
                    colorScheme == .dark ?
                    ModernDesignSystem.Colors.backgroundSecondaryDark :
                    ModernDesignSystem.Colors.backgroundSecondary
                )
                .ignoresSafeArea()
        )
        .overlay(
            Rectangle()
                .fill(ModernDesignSystem.Colors.divider)
                .frame(width: 1),
            alignment: .trailing
        )
    }
}

/// Sidebar section header
struct SidebarSection: View {
    let title: String
    
    var body: some View {
        Text(title.uppercased())
            .font(ModernDesignSystem.Typography.caption)
            .fontWeight(.semibold)
            .foregroundColor(ModernDesignSystem.Colors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .padding(.vertical, ModernDesignSystem.Spacing.xs)
    }
}

// MARK: - Empty State

/// Beautiful empty state view
struct ModernEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    @State private var animationAmount = 1.0
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animationAmount)
                    .animation(
                        .easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                        value: animationAmount
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.xs) {
                Text(title)
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(message)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .modernButton(.primary)
            }
        }
        .padding(ModernDesignSystem.Spacing.xl)
        .onAppear {
            animationAmount = 1.1
        }
    }
}

// MARK: - Search Bar

/// Modern search bar with animations
struct ModernSearchBar: View {
    @Binding var searchText: String
    let placeholder: String
    
    @FocusState private var isFocused: Bool
    @State private var showClearButton = false
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .font(.system(size: 16))
            
            TextField(placeholder, text: $searchText)
                .textFieldStyle(.plain)
                .font(ModernDesignSystem.Typography.body)
                .focused($isFocused)
                .onChange(of: searchText) { newValue in
                    withAnimation(ModernDesignSystem.Animation.easeOutFast) {
                        showClearButton = !newValue.isEmpty
                    }
                }
            
            if showClearButton {
                Button {
                    withAnimation(ModernDesignSystem.Animation.easeOutFast) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusFull)
                .fill(ModernDesignSystem.Colors.backgroundTertiary)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusFull)
                        .stroke(
                            isFocused ? ModernDesignSystem.Colors.primary : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .animation(ModernDesignSystem.Animation.easeOutFast, value: isFocused)
    }
}

// MARK: - Tabs

/// Modern tab view
struct ModernTabView<SelectionValue: Hashable>: View {
    let tabs: [(title: String, value: SelectionValue)]
    @Binding var selection: SelectionValue
    
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            ForEach(tabs, id: \.value) { tab in
                TabButton(
                    title: tab.title,
                    isSelected: selection == tab.value,
                    namespace: animation
                ) {
                    withAnimation(ModernDesignSystem.Animation.spring) {
                        selection = tab.value
                    }
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                .fill(ModernDesignSystem.Colors.backgroundTertiary)
        )
    }
    
    struct TabButton: View {
        let title: String
        let isSelected: Bool
        let namespace: Namespace.ID
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(ModernDesignSystem.Typography.callout)
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundColor(
                        isSelected ? ModernDesignSystem.Colors.textPrimary :
                        ModernDesignSystem.Colors.textSecondary
                    )
                    .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                    .padding(.vertical, ModernDesignSystem.Spacing.xs)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusXS)
                                    .fill(ModernDesignSystem.Colors.backgroundPrimary)
                                    .matchedGeometryEffect(id: "tab", in: namespace)
                            }
                        }
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Progress Indicator

/// Modern progress bar
struct ModernProgressBar: View {
    let progress: Double
    let height: CGFloat
    
    @State private var animatedProgress: Double = 0
    
    init(progress: Double, height: CGFloat = 4) {
        self.progress = min(max(progress, 0), 1)
        self.height = height
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(ModernDesignSystem.Colors.backgroundTertiary)
                    .frame(height: height)
                
                // Progress
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                ModernDesignSystem.Colors.primary,
                                ModernDesignSystem.Colors.primaryHover
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * animatedProgress, height: height)
                    .animation(ModernDesignSystem.Animation.spring, value: animatedProgress)
            }
        }
        .frame(height: height)
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { newValue in
            animatedProgress = newValue
        }
    }
}

// MARK: - Tooltip

/// Modern tooltip with smooth animations
struct ModernTooltip: View {
    let text: String
    let edge: Edge
    
    @State private var showTooltip = false
    
    var body: some View {
        Text(text)
            .font(ModernDesignSystem.Typography.caption)
            .foregroundColor(.white)
            .padding(.horizontal, ModernDesignSystem.Spacing.xs)
            .padding(.vertical, ModernDesignSystem.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusXS)
                    .fill(Color.black.opacity(0.8))
            )
            .scaleEffect(showTooltip ? 1 : 0.8)
            .opacity(showTooltip ? 1 : 0)
            .animation(ModernDesignSystem.Animation.easeOutFast, value: showTooltip)
            .onAppear {
                showTooltip = true
            }
    }
}

// MARK: - Floating Menu

/// Floating context menu
struct FloatingMenu<Content: View>: View {
    let items: [MenuItem]
    @Binding var isShowing: Bool
    
    struct MenuItem {
        let icon: String
        let title: String
        let action: () -> Void
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                MenuItemView(item: items[index]) {
                    items[index].action()
                    withAnimation(ModernDesignSystem.Animation.easeOutFast) {
                        isShowing = false
                    }
                }
                
                if index < items.count - 1 {
                    Divider()
                        .padding(.horizontal, ModernDesignSystem.Spacing.xs)
                }
            }
        }
        .frame(minWidth: 200)
        .glassCard()
        .scaleEffect(isShowing ? 1 : 0.9)
        .opacity(isShowing ? 1 : 0)
        .animation(ModernDesignSystem.Animation.spring, value: isShowing)
    }
    
    struct MenuItemView: View {
        let item: MenuItem
        let action: () -> Void
        
        @State private var isHovered = false
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Image(systemName: item.icon)
                        .font(.system(size: 16))
                        .frame(width: 20)
                    
                    Text(item.title)
                        .font(ModernDesignSystem.Typography.body)
                    
                    Spacer()
                }
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                .padding(.vertical, ModernDesignSystem.Spacing.xs)
                .background(
                    isHovered ? ModernDesignSystem.Colors.primary.opacity(0.1) : Color.clear
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(ModernDesignSystem.Animation.hover) {
                    isHovered = hovering
                }
            }
        }
    }
}

// MARK: - Timeline Card

/// Beautiful timeline card for journal entries
struct TimelineCard: View {
    let date: Date
    let title: String
    let preview: String
    let mood: MoodIndicator.Mood?
    let wordCount: Int
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                // Header
                HStack {
                    Text(date, style: .date)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                    
                    Spacer()
                    
                    if let mood = mood {
                        MoodIndicator(mood: mood, size: .small)
                    }
                }
                
                // Title
                Text(title)
                    .font(ModernDesignSystem.Typography.headline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                
                // Preview
                Text(preview)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Footer
                HStack {
                    Text("\(wordCount) words")
                        .font(ModernDesignSystem.Typography.footnote)
                        .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                    
                    Spacer()
                    
                    Text(date, style: .time)
                        .font(ModernDesignSystem.Typography.footnote)
                        .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                }
            }
            .cardPadding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                    .fill(
                        isSelected ? ModernDesignSystem.Colors.primary.opacity(0.1) :
                        isHovered ? ModernDesignSystem.Colors.backgroundSecondary :
                        ModernDesignSystem.Colors.backgroundPrimary
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                            .stroke(
                                isSelected ? ModernDesignSystem.Colors.primary :
                                ModernDesignSystem.Colors.border,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .shadow(
                color: isHovered ? ModernDesignSystem.Components.shadowMD.color : ModernDesignSystem.Components.shadowSM.color,
                radius: isHovered ? ModernDesignSystem.Components.shadowMD.radius : ModernDesignSystem.Components.shadowSM.radius,
                x: 0,
                y: isHovered ? ModernDesignSystem.Components.shadowMD.y : ModernDesignSystem.Components.shadowSM.y
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(ModernDesignSystem.Animation.spring) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Floating Compose Button

/// Floating action button for creating new entries
struct FloatingComposeButton: View {
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var rotation = 0.0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ModernDesignSystem.Colors.primary,
                                ModernDesignSystem.Colors.primaryHover
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Icon
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
            }
            .frame(width: 56, height: 56)
            .shadow(
                color: ModernDesignSystem.Colors.primary.opacity(0.4),
                radius: isHovered ? 16 : 12,
                x: 0,
                y: isHovered ? 8 : 6
            )
            .scaleEffect(isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(ModernDesignSystem.Animation.spring) {
                isHovered = hovering
                if hovering {
                    rotation = 90
                } else {
                    rotation = 0
                }
            }
        }
    }
}

// MARK: - Chat Message Bubble

/// Modern chat message bubble
struct ModernChatBubble: View {
    let message: String
    let isUser: Bool
    let timestamp: Date
    
    @State private var showTimestamp = false
    
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(isUser ? .white : ModernDesignSystem.Colors.textPrimary)
                    .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                    .padding(.vertical, ModernDesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(
                            cornerRadius: ModernDesignSystem.Components.radiusMD,
                            style: .continuous
                        )
                        .fill(
                            isUser ? ModernDesignSystem.Colors.primary :
                            ModernDesignSystem.Colors.backgroundTertiary
                        )
                    )
                    .onTapGesture {
                        withAnimation(ModernDesignSystem.Animation.easeOutFast) {
                            showTimestamp.toggle()
                        }
                    }
                
                if showTimestamp {
                    Text(timestamp, style: .time)
                        .font(ModernDesignSystem.Typography.footnote)
                        .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Skeleton Loader

/// Skeleton loading placeholder
struct SkeletonLoader: View {
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var shimmerOffset: CGFloat = -1
    
    init(height: CGFloat = 20, cornerRadius: CGFloat = 4) {
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(ModernDesignSystem.Colors.backgroundTertiary)
            .frame(height: height)
            .overlay(
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset * geometry.size.width)
                        .animation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: shimmerOffset
                        )
                }
            )
            .onAppear {
                shimmerOffset = 2
            }
    }
}