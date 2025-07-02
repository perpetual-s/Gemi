//
//  SimplifiedSidebar.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct SimplifiedSidebar: View {
    @Environment(NavigationModel.self) private var navigation
    @State private var hoveredSection: NavigationSection?
    
    private var sidebarWidth: CGFloat {
        navigation.isSidebarCollapsed ? 64 : 240
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo/App name
            sidebarHeader
            
            // Navigation sections
            VStack(spacing: ModernDesignSystem.Spacing.xxs) {
                ForEach(NavigationSection.allCases) { section in
                    if section == .settings {
                        Spacer()
                    }
                    
                    NavigationItem(
                        section: section,
                        isSelected: navigation.selectedSection == section,
                        isCollapsed: navigation.isSidebarCollapsed,
                        isHovered: hoveredSection == section
                    ) {
                        navigation.navigate(to: section)
                    }
                    .onHover { isHovered in
                        withAnimation(ModernDesignSystem.Animation.easeOutFast) {
                            hoveredSection = isHovered ? section : nil
                        }
                    }
                }
            }
            .padding(ModernDesignSystem.Spacing.xs)
        }
        .frame(width: sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(
            Rectangle()
                .fill(ModernDesignSystem.Colors.backgroundSecondary)
                .ignoresSafeArea()
        )
        .overlay(
            Rectangle()
                .fill(ModernDesignSystem.Colors.divider)
                .frame(width: 1),
            alignment: .trailing
        )
        .animation(ModernDesignSystem.Animation.spring, value: navigation.isSidebarCollapsed)
    }
    
    private var sidebarHeader: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 24))
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .frame(width: 32, height: 32)
            
            if !navigation.isSidebarCollapsed {
                Text("Gemi")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button(action: navigation.toggleSidebar) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16))
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
        .padding(.vertical, ModernDesignSystem.Spacing.md)
        .overlay(
            Rectangle()
                .fill(ModernDesignSystem.Colors.divider)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Navigation Item

struct NavigationItem: View {
    let section: NavigationSection
    let isSelected: Bool
    let isCollapsed: Bool
    let isHovered: Bool
    let action: () -> Void
    
    @State private var showTooltip = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Icon with color
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(section.color.opacity(0.1))
                            .frame(width: 32, height: 32)
                    }
                    
                    Image(systemName: section.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? section.color : ModernDesignSystem.Colors.textSecondary)
                        .animation(ModernDesignSystem.Animation.easeOutFast, value: isSelected)
                }
                .frame(width: 32, height: 32)
                
                if !isCollapsed {
                    Text(section.rawValue)
                        .font(ModernDesignSystem.Typography.callout)
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundColor(isSelected ? ModernDesignSystem.Colors.textPrimary : ModernDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(section.color)
                            .frame(width: 3, height: 20)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.xs)
            .padding(.vertical, ModernDesignSystem.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                    .fill(
                        isSelected ? section.color.opacity(0.08) :
                        isHovered ? ModernDesignSystem.Colors.backgroundTertiary :
                        Color.clear
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(section.keyboardShortcut ?? KeyEquivalent(""), modifiers: .command)
        .help(section.rawValue)
        .onHover { hovering in
            if isCollapsed && hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if hovering {
                        showTooltip = true
                    }
                }
            } else {
                showTooltip = false
            }
        }
        .popover(isPresented: $showTooltip, arrowEdge: .trailing) {
            Text(section.rawValue)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(.white)
                .padding(.horizontal, ModernDesignSystem.Spacing.xs)
                .padding(.vertical, ModernDesignSystem.Spacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusXS)
                        .fill(Color.black.opacity(0.8))
                )
        }
    }
}

// MARK: - Preview

struct SimplifiedSidebar_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 0) {
            SimplifiedSidebar()
            
            Spacer()
        }
        .frame(width: 800, height: 600)
        .environment(NavigationModel())
    }
}