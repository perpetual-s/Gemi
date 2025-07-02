//
//  TopToolbar.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct TopToolbar: View {
    let navigationModel: NavigationModel
    @FocusState.Binding var isSearchFocused: Bool
    let onNewEntry: () -> Void
    
    @State private var showUserMenu = false
    @State private var isSearchHovered = false
    @State private var showProfileView = false
    @State private var showStatisticsView = false
    @State private var showHelpView = false
    
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
        .sheet(isPresented: $showProfileView) {
            ProfileView()
        }
        .sheet(isPresented: $showStatisticsView) {
            StatisticsView()
        }
        .sheet(isPresented: $showHelpView) {
            HelpView()
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            TextField("Search entries...", text: .init(
                get: { navigationModel.searchQuery },
                set: { navigationModel.searchQuery = $0 }
            ))
            .textFieldStyle(.plain)
            .font(ModernDesignSystem.Typography.body)
            .focused($isSearchFocused)
            .onSubmit {
                navigationModel.activateSearch()
            }
            
            if !navigationModel.searchQuery.isEmpty {
                Button {
                    navigationModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            // Keyboard shortcut hint
            if !isSearchFocused && navigationModel.searchQuery.isEmpty {
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
                            isSearchFocused ? ModernDesignSystem.Colors.primary :
                            isSearchHovered ? ModernDesignSystem.Colors.border :
                            Color.clear,
                            lineWidth: isSearchFocused ? 2 : 1
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
            isSearchFocused = true
        }
        .keyboardShortcut("k", modifiers: .command)
    }
    
    // MARK: - New Entry Button
    
    private var newEntryButton: some View {
        Button(action: onNewEntry) {

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
                    if navigationModel.writingStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundColor(ModernDesignSystem.Colors.moodEnergetic)
                            
                            Text("\(navigationModel.writingStreak)")
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
            Image(systemName: navigationModel.syncStatus.icon)
                .font(.system(size: 12))
                .foregroundColor(navigationModel.syncStatus.color)
                .rotationEffect(
                    navigationModel.syncStatus.icon == "arrow.triangle.2.circlepath" ?
                    .degrees(360) : .zero
                )
                .animation(
                    navigationModel.syncStatus.icon == "arrow.triangle.2.circlepath" ?
                    .linear(duration: 1).repeatForever(autoreverses: false) :
                    .default,
                    value: navigationModel.syncStatus.icon
                )
            
            if case .error(let message) = navigationModel.syncStatus {
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
                .fill(navigationModel.syncStatus.color.opacity(0.1))
        )
    }
    
    // MARK: - User Menu
    
    @ViewBuilder
    private var userMenuContent: some View {
        Section {
            Button {
                showProfileView = true
            } label: {
                Label("Profile", systemImage: "person.circle")
            }
            
            Button {
                showStatisticsView = true
            } label: {
                Label("Writing Statistics", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
        
        Divider()
        
        Section {
            Button {
                navigationModel.navigate(to: .settings)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Button {
                showHelpView = true
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
        }
    }
}

// MARK: - Preview

struct TopToolbar_Previews: PreviewProvider {
    struct Preview: View {
        @FocusState var isSearchFocused: Bool
        
        var body: some View {
            VStack {
                TopToolbar(
                    navigationModel: NavigationModel(),
                    isSearchFocused: $isSearchFocused,
                    onNewEntry: { }
                )
                
                Spacer()
            }
            .frame(width: 1000, height: 600)
            .environment(NavigationModel())
        }
    }
    
    static var previews: some View {
        Preview()
    }
}