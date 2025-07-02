//
//  TopToolbar.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct TopToolbar: View {
    @Environment(NavigationModel.self) private var navigation
    @FocusState private var searchFieldFocused: Bool
    @State private var showUserMenu = false
    @State private var isSearchHovered = false
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            // Search bar
            searchBar
            
            Spacer()
            
            // New entry button
            newEntryButton
            
            // User info
            userSection
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
        .overlay(
            Rectangle()
                .fill(ModernDesignSystem.Colors.divider)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            TextField("Search entries...", text: .init(
                get: { navigation.searchQuery },
                set: { navigation.searchQuery = $0 }
            ))
            .textFieldStyle(.plain)
            .font(ModernDesignSystem.Typography.body)
            .focused($searchFieldFocused)
            .onSubmit {
                navigation.activateSearch()
            }
            
            if !navigation.searchQuery.isEmpty {
                Button {
                    navigation.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            // Keyboard shortcut hint
            if !searchFieldFocused && navigation.searchQuery.isEmpty {
                Text("⌘K")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ModernDesignSystem.Colors.backgroundTertiary)
                    )
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                .fill(ModernDesignSystem.Colors.backgroundTertiary)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                        .stroke(
                            searchFieldFocused ? ModernDesignSystem.Colors.primary :
                            isSearchHovered ? ModernDesignSystem.Colors.border :
                            Color.clear,
                            lineWidth: searchFieldFocused ? 2 : 1
                        )
                )
        )
        .frame(maxWidth: 400)
        .onHover { hovering in
            withAnimation(ModernDesignSystem.Animation.easeOutFast) {
                isSearchHovered = hovering
            }
        }
        .onTapGesture {
            searchFieldFocused = true
        }
        .keyboardShortcut("k", modifiers: .command)
    }
    
    // MARK: - New Entry Button
    
    private var newEntryButton: some View {
        Button {
            // TODO: Create new entry
        } label: {
            Label("New Entry", systemImage: "plus")
                .font(ModernDesignSystem.Typography.callout)
                .fontWeight(.medium)
        }
        .modernButton(.primary)
        .keyboardShortcut("n", modifiers: .command)
    }
    
    // MARK: - User Section
    
    private var userSection: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            // Sync status
            syncStatusIndicator
            
            Divider()
                .frame(height: 20)
            
            // User menu
            Menu {
                userMenuContent
            } label: {
                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                    // User avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ModernDesignSystem.Colors.primary,
                                    ModernDesignSystem.Colors.moodReflective
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("U")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        )
                    
                    // Streak counter
                    if navigation.writingStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundColor(ModernDesignSystem.Colors.moodEnergetic)
                            
                            Text("\(navigation.writingStreak)")
                                .font(ModernDesignSystem.Typography.callout)
                                .fontWeight(.medium)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(ModernDesignSystem.Colors.moodEnergetic.opacity(0.1))
                        )
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Sync Status
    
    private var syncStatusIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: navigation.syncStatus.icon)
                .font(.system(size: 12))
                .foregroundColor(navigation.syncStatus.color)
                .rotationEffect(
                    navigation.syncStatus.icon == "arrow.triangle.2.circlepath" ?
                    .degrees(360) : .zero
                )
                .animation(
                    navigation.syncStatus.icon == "arrow.triangle.2.circlepath" ?
                    .linear(duration: 1).repeatForever(autoreverses: false) :
                    .default,
                    value: navigation.syncStatus.icon
                )
            
            if case .error(let message) = navigation.syncStatus {
                Text(message)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.error)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(navigation.syncStatus.color.opacity(0.1))
        )
    }
    
    // MARK: - User Menu
    
    @ViewBuilder
    private var userMenuContent: some View {
        Section {
            Button {
                // TODO: Show profile
            } label: {
                Label("Profile", systemImage: "person.circle")
            }
            
            Button {
                // TODO: Show statistics
            } label: {
                Label("Writing Statistics", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
        
        Divider()
        
        Section {
            Button {
                navigation.navigate(to: .settings)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Button {
                // TODO: Show help
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
        }
        
        Divider()
        
        Button {
            // TODO: Sign out
        } label: {
            Label("Sign Out", systemImage: "arrow.right.square")
        }
    }
}

// MARK: - Preview

struct TopToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TopToolbar()
            
            Spacer()
        }
        .frame(width: 1000, height: 600)
        .environment(NavigationModel())
    }
}