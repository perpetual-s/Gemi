//
//  ModernDesignSystemDemo.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct ModernDesignSystemDemo: View {
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var showFloatingMenu = false
    @State private var progress = 0.7
    @State private var textFieldValue = ""
    @State private var showSuccessAnimation = false
    
    var body: some View {
        NavigationView {
            ModernSidebar {
                VStack(alignment: .leading, spacing: 0) {
                    // Search bar
                    ModernSearchBar(searchText: $searchText, placeholder: "Search entries...")
                        .padding(ModernDesignSystem.Spacing.md)
                    
                    // Sections
                    SidebarSection(title: "Journal")
                    
                    ModernListItem(content: {
                        Label("All Entries", systemImage: "book.fill")
                    }, action: {})
                    
                    ModernListItem(content: {
                        Label("Favorites", systemImage: "star.fill")
                    }, action: {})
                    
                    ModernListItem(content: {
                        Label("Recent", systemImage: "clock.fill")
                    }, action: {})
                    
                    SidebarSection(title: "Moods")
                    
                    ModernListItem(content: {
                        HStack {
                            MoodIndicator(mood: .happy, size: .small)
                            Text("Happy")
                        }
                    }, action: {})
                    
                    ModernListItem(content: {
                        HStack {
                            MoodIndicator(mood: .calm, size: .small)
                            Text("Calm")
                        }
                    }, action: {})
                    
                    Spacer()
                }
            }
            
            // Main content
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // Navigation bar
                    ModernNavigationBar(
                        title: "Modern Design System Demo",
                        leadingIcon: "sidebar.left",
                        leadingAction: {},
                        trailingIcon: "gear",
                        trailingAction: {}
                    )
                    
                    VStack(spacing: ModernDesignSystem.Spacing.xxl) {
                        // Typography section
                        typographySection
                        
                        Divider()
                        
                        // Colors section
                        colorsSection
                        
                        Divider()
                        
                        // Components section
                        componentsSection
                        
                        Divider()
                        
                        // Cards section
                        cardsSection
                        
                        Divider()
                        
                        // Animations section
                        animationsSection
                    }
                    .padding(ModernDesignSystem.Spacing.pageMargin)
                    .frame(maxWidth: ModernDesignSystem.Spacing.maxContentWidth)
                }
            }
            .background(ModernDesignSystem.Colors.canvas)
            
            // Floating compose button
            .overlay(
                FloatingComposeButton(action: {})
                    .padding(ModernDesignSystem.Spacing.lg),
                alignment: .bottomTrailing
            )
        }
    }
    
    // MARK: - Sections
    
    var typographySection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Typography")
                .modifier(FontModifier(font: ModernDesignSystem.Typography.title1))
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                Text("Display Text")
                    .modifier(FontModifier(font: ModernDesignSystem.Typography.display))
                
                Text("Title 1 - Semibold headers")
                    .modifier(FontModifier(font: ModernDesignSystem.Typography.title1))
                
                Text("Title 2 - Section headers")
                    .modifier(FontModifier(font: ModernDesignSystem.Typography.title2))
                
                Text("Headline - Emphasized text")
                    .modifier(FontModifier(font: ModernDesignSystem.Typography.headline))
                
                Text("Body - Regular paragraph text for comfortable reading")
                    .modifier(FontModifier(font: ModernDesignSystem.Typography.body))
                    .lineSpacing(4)
                
                Text("Caption - Small descriptive text")
                    .modifier(FontModifier(font: ModernDesignSystem.Typography.caption))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text("let code = \"SF Mono\"")
                    .modifier(FontModifier(font: ModernDesignSystem.Typography.mono))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ModernDesignSystem.Colors.backgroundTertiary)
                    )
            }
        }
    }
    
    var colorsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Colors")
                .modifier(FontModifier(font: ModernDesignSystem.Typography.title1))
            
            // Primary colors
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                ColorSwatch(color: ModernDesignSystem.Colors.primary, label: "Primary")
                ColorSwatch(color: ModernDesignSystem.Colors.primaryHover, label: "Hover")
                ColorSwatch(color: ModernDesignSystem.Colors.primaryPressed, label: "Pressed")
            }
            
            // Mood colors
            Text("Mood Accents")
                .modifier(FontModifier(font: ModernDesignSystem.Typography.headline))
                .padding(.top)
            
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                ColorSwatch(color: ModernDesignSystem.Colors.moodEnergetic, label: "Energetic")
                ColorSwatch(color: ModernDesignSystem.Colors.moodCalm, label: "Calm")
                ColorSwatch(color: ModernDesignSystem.Colors.moodReflective, label: "Reflective")
                ColorSwatch(color: ModernDesignSystem.Colors.moodHappy, label: "Happy")
                ColorSwatch(color: ModernDesignSystem.Colors.moodFocused, label: "Focused")
            }
            
            // Semantic colors
            Text("Semantic Colors")
                .modifier(FontModifier(font: ModernDesignSystem.Typography.headline))
                .padding(.top)
            
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                ColorSwatch(color: ModernDesignSystem.Colors.success, label: "Success")
                ColorSwatch(color: ModernDesignSystem.Colors.warning, label: "Warning")
                ColorSwatch(color: ModernDesignSystem.Colors.error, label: "Error")
                ColorSwatch(color: ModernDesignSystem.Colors.info, label: "Info")
            }
        }
    }
    
    var componentsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Components")
                .modifier(FontModifier(font: ModernDesignSystem.Typography.title1))
            
            // Buttons
            Text("Buttons")
                .modifier(FontModifier(font: ModernDesignSystem.Typography.headline))
            
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Button("Primary") {}
                    .modernButton(.primary)
                
                Button("Secondary") {}
                    .modernButton(.secondary)
                
                Button("Ghost") {}
                    .modernButton(.ghost)
            }
            
            // Text field
            Text("Input Fields")
                .modifier(FontModifier(font: ModernDesignSystem.Typography.headline))
                .padding(.top)
            
            ModernTextField(
                placeholder: "Enter your text here",
                text: $textFieldValue,
                icon: "pencil"
            )
            
            // Tabs
            Text("Tabs")
                .modifier(FontModifier(font: ModernDesignSystem.Typography.headline))
                .padding(.top)
            
            ModernTabView(
                tabs: [
                    ("Today", 0),
                    ("This Week", 1),
                    ("This Month", 2)
                ],
                selection: $selectedTab
            )
            
            // Progress bar
            Text("Progress")
                .modifier(FontModifier(font: ModernDesignSystem.Typography.headline))
                .padding(.top)
            
            ModernProgressBar(progress: progress)
                .frame(height: 8)
            
            // Loading spinner
            Text("Loading States")
                .modifier(FontModifier(font: ModernDesignSystem.Typography.headline))
                .padding(.top)
            
            HStack(spacing: ModernDesignSystem.Spacing.lg) {
                ModernLoadingSpinner()
                ModernTypingIndicator()
                SkeletonLoader(height: 20)
                    .frame(width: 200)
            }
        }
    }
    
    var cardsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Cards & Panels")
                .modifier(FontModifier(font: ModernDesignSystem.Typography.title1))
            
            // Timeline card
            TimelineCard(
                date: Date(),
                title: "My First Journal Entry",
                preview: "Today was an amazing day. I started using this beautiful new journal app and I'm excited to capture my thoughts...",
                mood: .happy,
                wordCount: 234,
                isSelected: false,
                action: {}
            )
            
            // Glass card
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                Text("Glass Morphism Card")
                    .modifier(FontModifier(font: ModernDesignSystem.Typography.headline))
                Text("This card uses glass morphism effect with blur and transparency")
                    .modifier(FontModifier(font: ModernDesignSystem.Typography.body))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .cardPadding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
            
            // Modern card
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                Text("Modern Card")
                    .modifier(FontModifier(font: ModernDesignSystem.Typography.headline))
                Text("Clean card with subtle shadow and border")
                    .modifier(FontModifier(font: ModernDesignSystem.Typography.body))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .cardPadding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .modernCard(elevation: .medium)
        }
    }
    
    var animationsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Animations")
                .modifier(FontModifier(font: ModernDesignSystem.Typography.title1))
            
            // Floating animation
            HStack(spacing: ModernDesignSystem.Spacing.lg) {
                Image(systemName: "star.fill")
                    .font(.system(size: 32))
                    .foregroundColor(ModernDesignSystem.Colors.moodHappy)
                    .floatingAnimation()
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundColor(ModernDesignSystem.Colors.moodEnergetic)
                    .pulseAnimation()
                
                Text("Shimmer")
                    .modifier(FontModifier(font: ModernDesignSystem.Typography.headline))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ModernDesignSystem.Colors.primary)
                    )
                    .foregroundColor(.white)
                    .shimmerAnimation()
            }
            
            // Success animation
            Button("Show Success") {
                showSuccessAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSuccessAnimation = false
                }
            }
            .modernButton(.primary)
            
            if showSuccessAnimation {
                SuccessCheckmark()
                    .transition(.modernScale)
            }
            
            // Empty state
            ModernEmptyState(
                icon: "doc.text",
                title: "No entries yet",
                message: "Start your journaling journey by creating your first entry",
                actionTitle: "Create Entry",
                action: {}
            )
            .frame(height: 300)
            .modernCard(elevation: .low)
        }
    }
}

// MARK: - Helper Views

struct ColorSwatch: View {
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 60, height: 60)
                .shadow(
                    color: color.opacity(0.3),
                    radius: 8,
                    y: 4
                )
            
            Text(label)
                .modifier(FontModifier(font: ModernDesignSystem.Typography.caption))
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
    }
}

struct FontModifier: ViewModifier {
    let font: Font
    
    func body(content: Content) -> some View {
        content.font(font)
    }
}

// MARK: - Preview

struct ModernDesignSystemDemo_Previews: PreviewProvider {
    static var previews: some View {
        ModernDesignSystemDemo()
            .frame(width: 1200, height: 800)
    }
}