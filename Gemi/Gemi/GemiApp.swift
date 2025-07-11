//
//  GemiApp.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/5/25.
//

import SwiftUI

@main
struct GemiApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var modelManager = GemmaModelManager()
    @AppStorage("hasCompletedGemmaOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false
    @State private var hasCheckedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.requiresInitialSetup {
                    InitialSetupView()
                } else if authManager.isAuthenticated {
                    if shouldShowOnboarding {
                        GemmaOnboardingView {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                hasCompletedOnboarding = true
                                showingOnboarding = false
                            }
                        }
                    } else {
                        MainWindowView()
                    }
                } else {
                    AuthenticationView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authManager.requiresInitialSetup)
            .task {
                // Check onboarding needs immediately
                await checkOnboardingStatus()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    NotificationCenter.default.post(name: .newEntry, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!authManager.isAuthenticated)
            }
            
            CommandGroup(after: .newItem) {
                Button("Command Palette") {
                    NotificationCenter.default.post(name: .showCommandPalette, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(!authManager.isAuthenticated)
                
                Divider()
                
                Button("Search") {
                    NotificationCenter.default.post(name: .search, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(!authManager.isAuthenticated)
                
                Button("Chat with Gemi") {
                    NotificationCenter.default.post(name: .openChat, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(!authManager.isAuthenticated)
            }
            
            CommandGroup(after: .appSettings) {
                Button("Lock Gemi") {
                    authManager.logout()
                }
                .keyboardShortcut("l", modifiers: [.command, .control])
                .disabled(!authManager.isAuthenticated)
            }
        }
    }
    
    var shouldShowOnboarding: Bool {
        // Only show onboarding if we've checked and determined it's needed
        hasCheckedOnboarding && showingOnboarding
    }
    
    @MainActor
    private func checkOnboardingStatus() async {
        // Don't re-check if already done
        guard !hasCheckedOnboarding else { return }
        
        // Check model status
        modelManager.checkStatus()
        
        // Wait a moment for status to update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Determine if onboarding is needed
        let needsOnboarding = !hasCompletedOnboarding && modelManager.status != .ready
        
        // Update state
        hasCheckedOnboarding = true
        showingOnboarding = needsOnboarding
    }
}

extension Notification.Name {
    static let newEntry = Notification.Name("newEntry")
    static let search = Notification.Name("search")
    static let openChat = Notification.Name("openChat")
    static let showCommandPalette = Notification.Name("showCommandPalette")
}
