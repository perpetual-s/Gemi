//
//  ContentView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

/// ContentView presents Gemi's simplified navigation architecture focusing on journaling
struct ContentView: View {
    
    // MARK: - Dependencies
    
    @Environment(JournalStore.self) private var journalStore
    @Environment(PerformanceOptimizer.self) private var performanceOptimizer
    @Environment(AccessibilityManager.self) private var accessibilityManager
    @Environment(KeyboardNavigationState.self) private var keyboardNavigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - State
    
    @State private var navigationModel = NavigationModel()
    @State private var selectedEntry: JournalEntry?
    @State private var showingAIAssistant = false
    @State private var showingSettings = false
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            TopToolbar(
                navigationModel: navigationModel,
                isSearchFocused: $isSearchFocused,
                onNewEntry: {
                    navigationModel.openNewEntry()
                }
            )
            
            // Main content with sidebar
            HStack(spacing: 0) {
                // Simplified sidebar
                SimplifiedSidebar()
                    .environment(navigationModel)
                
                // Content area
                mainContentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.backgroundPrimary)
        .environment(navigationModel)
        .onAppear {
            Task {
                await journalStore.refreshEntries()
                updateWritingStreak()
            }
        }
        .onChange(of: journalStore.entries.count) { _, _ in
            updateWritingStreak()
        }
        .onKeyPress(.escape) {
            if navigationModel.showingEditor {
                navigationModel.closeEditor()
                return .handled
            }
            return .ignored
        }
    }
    
    // MARK: - Main Content Area
    
    @ViewBuilder
    private var mainContentArea: some View {
        ZStack {
            switch navigationModel.selectedSection {
            case .today:
                TodayView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                
            case .entries:
                if navigationModel.showingEditor {
                    FloatingComposeView(entry: .constant(navigationModel.editingEntry), onSave: {
                        navigationModel.closeEditor()
                        Task {
                            await journalStore.refreshEntries()
                        }
                    }, onCancel: {
                        navigationModel.closeEditor()
                    })
                    .padding(32)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: -20)),
                        removal: .opacity.combined(with: .offset(y: 20))
                    ))
                } else {
                    TimelineView(selectedEntry: $selectedEntry) {
                        navigationModel.openNewEntry()
                    }
                    .padding(32)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                }
                
            case .insights:
                InsightsView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                
            case .settings:
                SettingsView(isPresented: .constant(true))
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
            }
        }
        .animation(reduceMotion ? .linear(duration: 0.1) : DesignSystem.Animation.standard, value: navigationModel.selectedSection)
        .animation(reduceMotion ? .linear(duration: 0.1) : DesignSystem.Animation.cozySettle, value: navigationModel.showingEditor)
        .overlay {
            // AI Assistant overlay when requested from editor
            if showingAIAssistant {
                ChatView(isPresented: $showingAIAssistant)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateWritingStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let hasEntryToday = journalStore.entries.contains { entry in
            calendar.isDate(entry.createdAt, inSameDayAs: today)
        }
        
        // Simple streak calculation (can be enhanced)
        navigationModel.updateWritingStreak(hasEntryToday ? 1 : 0)
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
    
    ContentView()
        .environment(store)
        .environment(PerformanceOptimizer())
        .environment(AccessibilityManager())
        .environment(KeyboardNavigationState())
        .frame(width: 1400, height: 900)
}