//
//  GemiApp.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/28/25.
//

import SwiftUI

@main
struct GemiApp: App {
    
    // MARK: - Dependencies
    
    /// Global authentication manager
    @State private var authenticationManager = AuthenticationManager()
    
    /// Global journal store
    @State private var journalStore: JournalStore?
    
    /// Error state for initialization failures
    @State private var initializationError: Error?
    @State private var showingErrorAlert = false
    
    /// Onboarding state
    @State private var onboardingState = OnboardingState()
    
    /// Settings store
    @State private var settingsStore = SettingsStore()
    
    /// Window state manager for premium window behavior
    @State private var windowStateManager = WindowStateManager()
    
    /// Performance optimizer for 60fps animations
    @State private var performanceOptimizer = PerformanceOptimizer()
    
    /// Accessibility manager for VoiceOver and system preferences
    @State private var accessibilityManager = AccessibilityManager()
    
    /// Keyboard navigation state
    @State private var keyboardNavigation = KeyboardNavigationState()
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let journalStore = journalStore {
                    // Main application interface - no authentication or onboarding required
                    MainWindowView()
                        .environment(authenticationManager)
                        .environment(journalStore)
                        .environment(onboardingState)
                        .environment(settingsStore)
                        .environment(windowStateManager)
                        .environment(performanceOptimizer)
                        .environment(accessibilityManager)
                        .environment(keyboardNavigation)
                        .preferredColorScheme(nil) // Respect system appearance
                    .frame(minWidth: 800, idealWidth: 1200, maxWidth: .infinity, 
                           minHeight: 600, idealHeight: 800, maxHeight: .infinity)
                    .background(DesignSystem.Colors.backgroundPrimary)
                    .premiumWindowStyle()
                    .task {
                        // Initialize premium features
                        performanceOptimizer.startMonitoring()
                        
                        // Load initial data on app launch
                        await journalStore.loadEntries()
                    }
                } else {
                    // Error state UI
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        
                        Text("Failed to Initialize Gemi")
                            .font(.title)
                            .fontWeight(.semibold)
                        
                        Text(initializationError?.localizedDescription ?? "An unexpected error occurred while starting the application.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                        
                        HStack(spacing: 12) {
                            Button("Retry") {
                                initializeJournalStore()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Quit") {
                                NSApplication.shared.terminate(nil)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(40)
                    .frame(minWidth: 600, minHeight: 400)
                    .task {
                        initializeJournalStore()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) { _ in
                if let window = NSApp.mainWindow {
                    windowStateManager.saveWindowState(frame: window.frame)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
                windowStateManager.setFullScreen(true)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
                windowStateManager.setFullScreen(false)
            }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(
            width: 1000,
            height: 700
        )
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            GemiKeyboardCommands()
        }
    }
}

// MARK: - Helper Methods

extension GemiApp {
    /// Initialize the journal store with proper error handling
    private func initializeJournalStore() {
        do {
            let store = try JournalStore()
            journalStore = store
            initializationError = nil
        } catch {
            print("❌ Failed to initialize JournalStore: \(error)")
            initializationError = error
            journalStore = nil
        }
    }
}

// MARK: - Authentication Flow
// Authentication has been removed - app now launches directly into ContentView

// MARK: - Main Application Interface

/// The modern floating panel interface for Gemi
/// This view is defined in MainWindowView.swift

// MARK: - Placeholder Views

// Settings view is now defined in Views/Settings/SettingsView.swift
