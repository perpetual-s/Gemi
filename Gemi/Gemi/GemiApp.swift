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
    @StateObject private var ollamaLauncher = OllamaLauncher.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.requiresInitialSetup {
                    InitialSetupView()
                } else if authManager.isAuthenticated {
                    MainWindowView()
                } else {
                    AuthenticationView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authManager.requiresInitialSetup)
            .task {
                // Auto-launch Ollama on app startup
                await ollamaLauncher.checkAndLaunchOllama()
            }
            .environmentObject(ollamaLauncher)
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
}

extension Notification.Name {
    static let newEntry = Notification.Name("newEntry")
    static let search = Notification.Name("search")
    static let openChat = Notification.Name("openChat")
    static let showCommandPalette = Notification.Name("showCommandPalette")
}
