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
    @AppStorage("hasCompletedGemmaOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false
    @State private var hasCheckedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                // CRITICAL: Show loading state while checking onboarding status
                // This prevents ANY main UI from appearing before onboarding check
                if !hasCheckedOnboarding {
                    // Beautiful loading screen while checking
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.1, green: 0.05, blue: 0.2),
                                Color(red: 0.05, green: 0.05, blue: 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    }
                    .frame(width: 900, height: 700)
                    .frame(maxWidth: 900, maxHeight: 700)
                } else if authManager.requiresInitialSetup || shouldShowOnboarding {
                    // New users go directly to beautiful onboarding (which includes password setup)
                    GemmaOnboardingView {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            hasCompletedOnboarding = true
                            showingOnboarding = false
                        }
                    }
                    .frame(width: 900, height: 700)
                    .frame(maxWidth: 900, maxHeight: 700)
                    .background(Color.black)
                } else if authManager.isAuthenticated {
                    MainWindowView()
                } else {
                    AuthenticationView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authManager.requiresInitialSetup)
            .animation(.easeInOut(duration: 0.3), value: hasCheckedOnboarding)
            .task {
                // Check onboarding needs immediately
                await checkOnboardingStatus()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
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
        
        // First, check if we've completed onboarding before
        if hasCompletedOnboarding {
            // If yes, no need to show onboarding
            hasCheckedOnboarding = true
            showingOnboarding = false
            return
        }
        
        // If not completed, check if model is loaded
        let isModelReady = await NativeChatService.shared.health().modelLoaded
        
        // Show onboarding if:
        // 1. Never completed onboarding AND
        // 2. Model is not loaded
        let needsOnboarding = !hasCompletedOnboarding && !isModelReady
        
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
