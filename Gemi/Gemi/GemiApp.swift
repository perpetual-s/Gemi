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
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    NotificationCenter.default.post(name: .newEntry, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!authManager.isAuthenticated)
            }
            
            CommandGroup(after: .newItem) {
                Button("Search") {
                    NotificationCenter.default.post(name: .search, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
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
}
