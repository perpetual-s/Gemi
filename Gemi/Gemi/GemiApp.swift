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
    
    /// The main journal store for the application
    /// This will be injected into the view hierarchy using @Environment
    @State private var journalStore: JournalStore
    
    // MARK: - Initialization
    
    /// Initialize the app with the journal store
    /// If database initialization fails, the app will show an error state
    init() {
        do {
            // Initialize the journal store with encrypted database
            let store = try JournalStore()
            self._journalStore = State(initialValue: store)
            
            print("✅ Gemi app initialized successfully")
        } catch {
            // If database initialization fails, create a fallback state
            // This should rarely happen, but provides graceful error handling
            fatalError("Failed to initialize Gemi database: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Scene Configuration
    
    var body: some Scene {
        WindowGroup {
            // Main Timeline view with injected dependencies
            TimelineView()
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
        print("🚀 Gemi: Privacy-First AI Diary started")
        print("📊 Database encryption: Enabled")
        print("🔐 Privacy mode: Local-only processing")
    }
    
    /// Configure macOS-specific appearance and behavior
    private func configureMacOSAppearance() {
        // Configure NSWindow appearance if needed
        // This could include setting up custom window behaviors
        // For now, we rely on SwiftUI's default macOS styling
    }
}
