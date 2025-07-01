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
    @State private var journalStore: JournalStore = {
        do {
            return try JournalStore()
        } catch {
            fatalError("Failed to initialize JournalStore: \(error)")
        }
    }()
    
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
                if !onboardingState.hasCompletedOnboarding {
                    // Onboarding flow for first-time users
                    OnboardingView()
                        .environment(onboardingState)
                        .environment(windowStateManager)
                } else if authenticationManager.isAuthenticated {
                    // Main application interface
                    ContentView()
                        .environment(authenticationManager)
                        .environment(journalStore)
                        .environment(onboardingState)
                        .environment(settingsStore)
                        .environment(windowStateManager)
                        .environment(performanceOptimizer)
                        .environment(accessibilityManager)
                        .environment(keyboardNavigation)
                        .preferredColorScheme(nil) // Respect system appearance
                } else {
                    // Authentication flow
                    AuthenticationFlowView()
                        .environment(authenticationManager)
                        .environment(onboardingState)
                        .environment(windowStateManager)
                }
            }
            .frame(minWidth: 1000, minHeight: 600)
            .background(Color(red: 0.98, green: 0.98, blue: 0.98))
            .premiumWindowStyle()
            .task {
                // Initialize premium features
                performanceOptimizer.startMonitoring()
                
                // Load initial data on app launch
                await journalStore.loadEntries()
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
        .windowResizability(.contentSize)
        .defaultSize(
            width: 1200,
            height: 800
        )
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            GemiKeyboardCommands()
        }
    }
}

// MARK: - Authentication Flow

/// Handles the authentication flow before accessing the main app
struct AuthenticationFlowView: View {
    @Environment(AuthenticationManager.self) private var authManager
    
    var body: some View {
        Group {
            if authManager.isFirstTimeSetup {
                WelcomeView()
            } else {
                LoginView()
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
        .background(DesignSystem.Colors.systemBackground)
    }
}

// MARK: - Main Application Interface

/// The modern floating panel interface for Gemi
/// This view is defined in MainWindowView.swift

// MARK: - Placeholder Views

// Settings view is now defined in Views/Settings/SettingsView.swift

// MARK: - Menu Commands

struct GemiCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Entry") {
                // Handle new entry command
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Button("Talk to Gemi") {
                // Handle chat command
            }
            .keyboardShortcut("t", modifiers: .command)
        }
    }
}
