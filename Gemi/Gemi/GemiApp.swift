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
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if authenticationManager.isAuthenticated {
                    // Main application interface
                    ContentView()
                        .environment(authenticationManager)
                        .environment(journalStore)
                        .preferredColorScheme(nil) // Respect system appearance
                } else {
                    // Authentication flow
                    AuthenticationFlowView()
                        .environment(authenticationManager)
                }
            }
            .task {
                // Load initial data on app launch
                await journalStore.loadEntries()
                }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 800)
        .windowToolbarStyle(.unified)
        .commands {
            GemiCommands()
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

struct ChatView: View {
    var body: some View {
        VStack {
            Text("Chat with Gemi")
                .font(DesignSystem.Typography.title2)
            Text("Coming soon...")
                .font(DesignSystem.Typography.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Talk to Gemi")
    }
}

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .font(DesignSystem.Typography.title2)
            Text("Coming soon...")
                .font(DesignSystem.Typography.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
    }
}

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
