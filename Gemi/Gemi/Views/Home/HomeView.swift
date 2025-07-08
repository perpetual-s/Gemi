//
//  HomeView.swift
//  Gemi
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var journalStore: JournalStore
    let onNewEntry: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Theme.Colors.windowBackground,
                    Theme.Colors.windowBackground.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Beautiful empty state view - always shown as home
            EmptyStateView()
        }
    }
}