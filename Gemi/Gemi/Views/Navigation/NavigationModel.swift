//
//  NavigationModel.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI
import Observation

/// Navigation sections in the app
enum NavigationSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case entries = "Entries"
    case insights = "Insights"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .entries: return "book.fill"
        case .insights: return "lightbulb.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    var keyboardShortcut: KeyEquivalent? {
        switch self {
        case .today: return "1"
        case .entries: return "2"
        case .insights: return "3"
        case .settings: return ","
        }
    }
    
    var color: Color {
        switch self {
        case .today: return ModernDesignSystem.Colors.moodHappy
        case .entries: return ModernDesignSystem.Colors.primary
        case .insights: return ModernDesignSystem.Colors.moodReflective
        case .settings: return ModernDesignSystem.Colors.textSecondary
        }
    }
}

/// Main navigation state manager
@Observable
final class NavigationModel {
    // MARK: - Properties
    
    /// Currently selected section
    var selectedSection: NavigationSection = .today
    
    /// Sidebar collapsed state
    var isSidebarCollapsed: Bool = false
    
    /// Search query
    var searchQuery: String = ""
    
    /// Show search interface
    var isSearchActive: Bool = false
    
    /// Writing streak count
    var writingStreak: Int = 0
    
    /// Sync status
    var syncStatus: SyncStatus = .synced
    
    // MARK: - Private Properties
    
    private let defaults = UserDefaults.standard
    private let sidebarStateKey = "NavigationModel.isSidebarCollapsed"
    private let selectedSectionKey = "NavigationModel.selectedSection"
    
    // MARK: - Initialization
    
    init() {
        loadPersistedState()
    }
    
    // MARK: - Methods
    
    /// Navigate to a specific section
    func navigate(to section: NavigationSection) {
        withAnimation(ModernDesignSystem.Animation.spring) {
            selectedSection = section
        }
        savePersistedState()
    }
    
    /// Toggle sidebar collapsed state
    func toggleSidebar() {
        withAnimation(ModernDesignSystem.Animation.spring) {
            isSidebarCollapsed.toggle()
        }
        savePersistedState()
    }
    
    /// Activate search with optional query
    func activateSearch(with query: String? = nil) {
        withAnimation(ModernDesignSystem.Animation.easeOutFast) {
            isSearchActive = true
            if let query = query {
                searchQuery = query
            }
        }
    }
    
    /// Deactivate search
    func deactivateSearch() {
        withAnimation(ModernDesignSystem.Animation.easeOutFast) {
            isSearchActive = false
            searchQuery = ""
        }
    }
    
    /// Update writing streak
    func updateWritingStreak(_ count: Int) {
        withAnimation(ModernDesignSystem.Animation.spring) {
            writingStreak = count
        }
    }
    
    /// Update sync status
    func updateSyncStatus(_ status: SyncStatus) {
        withAnimation(ModernDesignSystem.Animation.easeOutFast) {
            syncStatus = status
        }
    }
    
    // MARK: - Persistence
    
    private func loadPersistedState() {
        isSidebarCollapsed = defaults.bool(forKey: sidebarStateKey)
        
        if let sectionRawValue = defaults.string(forKey: selectedSectionKey),
           let section = NavigationSection(rawValue: sectionRawValue) {
            selectedSection = section
        }
    }
    
    private func savePersistedState() {
        defaults.set(isSidebarCollapsed, forKey: sidebarStateKey)
        defaults.set(selectedSection.rawValue, forKey: selectedSectionKey)
    }
}

// MARK: - Supporting Types

enum SyncStatus {
    case synced
    case syncing
    case error(String)
    case offline
    
    var icon: String {
        switch self {
        case .synced: return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle.fill"
        case .offline: return "wifi.slash"
        }
    }
    
    var color: Color {
        switch self {
        case .synced: return ModernDesignSystem.Colors.success
        case .syncing: return ModernDesignSystem.Colors.primary
        case .error: return ModernDesignSystem.Colors.error
        case .offline: return ModernDesignSystem.Colors.textTertiary
        }
    }
}