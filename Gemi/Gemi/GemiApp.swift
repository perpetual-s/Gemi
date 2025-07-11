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
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.requiresInitialSetup {
                    InitialSetupView()
                } else if authManager.isAuthenticated {
                    if showingOnboarding {
                        GemmaOnboardingView {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                hasCompletedOnboarding = true
                                showingOnboarding = false
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.1)),
                            removal: .opacity.combined(with: .scale(scale: 0.9))
                        ))
                    } else {
                        MainWindowView()
                            .onAppear {
                                checkOnboardingNeeded()
                            }
                    }
                } else {
                    AuthenticationView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authManager.requiresInitialSetup)
            .animation(.easeInOut(duration: 0.5), value: showingOnboarding)
            .task {
                // Check model status on launch
                modelManager.checkStatus()
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
    
    private func checkOnboardingNeeded() {
        // Show onboarding if:
        // 1. User hasn't completed onboarding before
        // 2. Gemma 3n is not installed
        if !hasCompletedOnboarding && modelManager.status != .ready {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showingOnboarding = true
                }
            }
        }
    }
}

extension Notification.Name {
    static let newEntry = Notification.Name("newEntry")
    static let search = Notification.Name("search")
    static let openChat = Notification.Name("openChat")
    static let showCommandPalette = Notification.Name("showCommandPalette")
}
