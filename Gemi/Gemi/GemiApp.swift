//
//  GemiApp.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/28/25.
//

import SwiftUI

@main
struct GemiApp: App {
    
    // MARK: - Properties
    
    /// The authentication manager for session-based authentication
    /// This handles all authentication state and biometric/password verification
    @State private var authenticationManager = AuthenticationManager()
    
    /// The main journal store for the application
    /// This will be injected into the view hierarchy using @Environment
    @State private var journalStore: JournalStore
    

    
    // MARK: - Initialization
    
    /// Initialize the app with the journal store and authentication
    /// If database initialization fails, the app will show an error state
    init() {
        do {
            // Initialize the journal store with encrypted database
            let store = try JournalStore()
            self._journalStore = State(initialValue: store)
            
            print("Gemi app initialized successfully")
        } catch {
            // If database initialization fails, create a fallback state
            // This should rarely happen, but provides graceful error handling
            fatalError("Failed to initialize Gemi database: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Scene Configuration
    
    var body: some Scene {
        WindowGroup {
            // Main app content with authentication integration
            MainAppView()
                .environment(authenticationManager) // Swift 6 dependency injection
                .environment(journalStore) // Swift 6 dependency injection
                .onAppear {
                    setupApp()
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
    }
    
    // MARK: - App Setup
    
    /// Performs initial app setup and configuration
    private func setupApp() {
        // Configure app-wide settings
        configureMacOSAppearance()
        
        // Log app startup
        print("Gemi: Privacy-First AI Diary started")
        print("Database encryption: Enabled")
        print("Privacy mode: Local-only processing")
        print("Authentication: Session-based (\(authenticationManager.preferredAuthenticationMethod.displayName))")
    }
    
    /// Configure macOS-specific appearance and behavior
    private func configureMacOSAppearance() {
        // Configure NSWindow appearance if needed
        // This could include setting up custom window behaviors
        // For now, we rely on SwiftUI's default macOS styling
    }
    

}

// MARK: - Main App View

/// The main app view that handles authentication flow vs main interface
struct MainAppView: View {
    
    // MARK: - Environment
    
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(JournalStore.self) private var journalStore
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - State
    
    @State private var showingAuthenticationFailure = false
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // User is authenticated - show main app interface
                TimelineView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                // User needs authentication - show authentication flow
                authenticationFlow
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: authManager.isAuthenticated)
        .onChange(of: authManager.authenticationError) { _, error in
            // Handle authentication errors that require special UI
            if let error = error, shouldShowFailureView(for: error) {
                showingAuthenticationFailure = true
            }
        }
        .sheet(isPresented: $showingAuthenticationFailure) {
            if let error = authManager.authenticationError {
                AuthenticationFailedView(error: error)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    // MARK: - Authentication Flow
    
    @ViewBuilder
    private var authenticationFlow: some View {
        if authManager.isFirstTimeSetup {
            // First time user - show welcome and setup
            WelcomeView()
        } else {
            // Returning user - show login
            LoginView()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Determines if an authentication error should show the failure view
    private func shouldShowFailureView(for error: AuthenticationError) -> Bool {
        switch error {
        case .biometricLockout, .keychainError, .unknownError:
            return true
        case .biometricNotAvailable, .biometricNotEnrolled:
            // These are handled inline in LoginView
            return false
        case .passwordRequired, .passwordIncorrect, .userCancelled:
            // These are handled inline in LoginView
            return false
        }
    }
    
    /// Handle app lifecycle changes for session management
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active - check if session is still valid
            if authManager.isAuthenticated && !authManager.isSessionValid() {
                print("Session expired - requiring re-authentication")
                authManager.signOut()
            }
            
        case .inactive:
            // App became inactive (e.g., switching apps) - maintain session
            print("App became inactive - maintaining session")
            
        case .background:
            // App went to background - session remains valid but prepare for potential timeout
            print("App backgrounded - session maintained with timeout monitoring")
            
        @unknown default:
            break
        }
    }
}
