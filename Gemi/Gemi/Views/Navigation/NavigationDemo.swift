//
//  NavigationDemo.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct NavigationDemo: View {
    @State private var navigation = NavigationModel()
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            SimplifiedSidebar()
            
            // Main content
            VStack(spacing: 0) {
                TopToolbar(
                    navigationModel: navigation,
                    isSearchFocused: $isSearchFocused,
                    onNewEntry: { }
                )
                
                // Content area
                ScrollView {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xl) {
                        Text("Navigation Demo")
                            .font(ModernDesignSystem.Typography.display)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text("Selected Section: \(navigation.selectedSection.rawValue)")
                            .font(ModernDesignSystem.Typography.headline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        // Demo content
                        ForEach(0..<5) { index in
                            DemoCard(index: index)
                        }
                    }
                    .padding(ModernDesignSystem.Spacing.lg)
                    .frame(maxWidth: ModernDesignSystem.Spacing.maxContentWidth)
                    .frame(maxWidth: .infinity)
                }
                .background(ModernDesignSystem.Colors.backgroundPrimary)
            }
        }
        .environment(navigation)
    }
}

struct DemoCard: View {
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Demo Card \(index + 1)")
                .font(ModernDesignSystem.Typography.headline)
            
            Text("This is a demonstration of the new navigation system with modern design.")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .cardPadding()
        .modernCard(elevation: .medium)
    }
}

// MARK: - Preview

struct NavigationDemo_Previews: PreviewProvider {
    static var previews: some View {
        NavigationDemo()
            .frame(width: 1200, height: 800)
    }
}