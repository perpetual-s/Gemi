//
//  HelpView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection = HelpSection.gettingStarted
    @State private var searchQuery = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            HStack(spacing: 0) {
                // Sidebar
                sidebar
                
                Divider()
                
                // Main content
                ScrollView {
                    contentForSection(selectedSection)
                        .padding(ModernDesignSystem.Spacing.lg)
                }
            }
        }
        .frame(width: 800, height: 600)
        .background(ModernDesignSystem.Colors.backgroundPrimary)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Help & Support")
                .font(ModernDesignSystem.Typography.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ModernDesignSystem.Colors.textSecondary)
                
                TextField("Search help...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(ModernDesignSystem.Typography.body)
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.sm)
            .padding(.vertical, 6)
            .frame(width: 200)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusXS)
                    .fill(ModernDesignSystem.Colors.backgroundSecondary)
            )
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(ModernDesignSystem.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(ModernDesignSystem.Spacing.md)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            ForEach(HelpSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack {
                        Image(systemName: section.icon)
                            .frame(width: 20)
                        
                        Text(section.title)
                            .font(ModernDesignSystem.Typography.body)
                        
                        Spacer()
                    }
                    .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusXS)
                            .fill(selectedSection == section ? ModernDesignSystem.Colors.primary.opacity(0.1) : Color.clear)
                    )
                    .foregroundStyle(
                        selectedSection == section ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textPrimary
                    )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Contact support
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                Text("Need more help?")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundStyle(ModernDesignSystem.Colors.textSecondary)
                
                Button {
                    NSWorkspace.shared.open(URL(string: "mailto:support@gemi.app")!)
                } label: {
                    Label("Contact Support", systemImage: "envelope")
                        .font(ModernDesignSystem.Typography.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ModernDesignSystem.Colors.primary)
            }
            .padding(ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                    .fill(ModernDesignSystem.Colors.backgroundSecondary)
            )
        }
        .padding(ModernDesignSystem.Spacing.md)
        .frame(width: 250)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func contentForSection(_ section: HelpSection) -> some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
            Text(section.title)
                .font(ModernDesignSystem.Typography.title1)
                .fontWeight(.semibold)
                .foregroundStyle(ModernDesignSystem.Colors.textPrimary)
            
            switch section {
            case .gettingStarted:
                gettingStartedContent
            case .writingEntries:
                writingEntriesContent
            case .aiFeatures:
                aiFeaturesContent
            case .privacy:
                privacyContent
            case .shortcuts:
                shortcutsContent
            case .troubleshooting:
                troubleshootingContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Content Sections
    
    private var gettingStartedContent: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HelpSection.text("Welcome to Gemi, your private AI-powered journal.")
            
            HelpSection.heading("First Steps")
            HelpSection.bulletPoint("Click the '+' button or press ⌘N to create your first entry")
            HelpSection.bulletPoint("Write freely - Gemi automatically saves your work")
            HelpSection.bulletPoint("Use the AI chat to reflect on your thoughts")
            
            HelpSection.heading("Key Features")
            HelpSection.bulletPoint("100% offline - your data never leaves your device")
            HelpSection.bulletPoint("AI-powered insights and reflection")
            HelpSection.bulletPoint("Beautiful, distraction-free writing environment")
            HelpSection.bulletPoint("Automatic organization and search")
        }
    }
    
    private var writingEntriesContent: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HelpSection.text("Gemi makes journaling effortless and enjoyable.")
            
            HelpSection.heading("Creating Entries")
            HelpSection.bulletPoint("Click '+' or press ⌘N to start a new entry")
            HelpSection.bulletPoint("Add an optional title for easy reference")
            HelpSection.bulletPoint("Write naturally - formatting is automatic")
            
            HelpSection.heading("Editing & Organizing")
            HelpSection.bulletPoint("Click any entry in the timeline to edit")
            HelpSection.bulletPoint("Use search (⌘K) to find specific entries")
            HelpSection.bulletPoint("Sort by date or length using the menu")
            HelpSection.bulletPoint("Export entries as Markdown files")
        }
    }
    
    private var aiFeaturesContent: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HelpSection.text("Gemi's AI helps you reflect and gain insights.")
            
            HelpSection.heading("AI Chat")
            HelpSection.bulletPoint("Click the chat button to start a conversation")
            HelpSection.bulletPoint("Ask questions about your journal entries")
            HelpSection.bulletPoint("Get insights about patterns and themes")
            HelpSection.bulletPoint("All processing happens locally on your device")
            
            HelpSection.heading("Memory System")
            HelpSection.bulletPoint("Gemi remembers important details from your entries")
            HelpSection.bulletPoint("View and manage memories in the Memory Panel")
            HelpSection.bulletPoint("Delete specific memories or clear all")
            HelpSection.bulletPoint("Control what the AI remembers about you")
        }
    }
    
    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HelpSection.text("Your privacy is our top priority.")
            
            HelpSection.heading("Data Storage")
            HelpSection.bulletPoint("All data stored locally on your Mac")
            HelpSection.bulletPoint("Encrypted with AES-256-GCM encryption")
            HelpSection.bulletPoint("No cloud sync or external servers")
            HelpSection.bulletPoint("You own and control all your data")
            
            HelpSection.heading("AI Processing")
            HelpSection.bulletPoint("Gemma 3n model runs entirely offline")
            HelpSection.bulletPoint("No data sent to external AI services")
            HelpSection.bulletPoint("Conversations stay on your device")
            HelpSection.bulletPoint("Complete privacy for your thoughts")
        }
    }
    
    private var shortcutsContent: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HelpSection.text("Keyboard shortcuts for efficient journaling.")
            
            HelpSection.shortcut("⌘N", "New entry")
            HelpSection.shortcut("⌘S", "Save entry")
            HelpSection.shortcut("⌘K", "Search entries")
            HelpSection.shortcut("⌘T", "Open AI chat")
            HelpSection.shortcut("⌘,", "Open settings")
            HelpSection.shortcut("⌘1", "Go to Today view")
            HelpSection.shortcut("⌘2", "Go to Entries")
            HelpSection.shortcut("⌘3", "Go to Insights")
            HelpSection.shortcut("ESC", "Close current panel")
        }
    }
    
    private var troubleshootingContent: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HelpSection.text("Solutions to common issues.")
            
            HelpSection.heading("AI Not Responding")
            HelpSection.bulletPoint("Ensure Ollama is installed and running")
            HelpSection.bulletPoint("Check that gemma3n:e2b model is downloaded")
            HelpSection.bulletPoint("Restart Gemi if issues persist")
            
            HelpSection.heading("Can't Save Entries")
            HelpSection.bulletPoint("Check disk space availability")
            HelpSection.bulletPoint("Verify app permissions in System Settings")
            HelpSection.bulletPoint("Try resetting app data in Settings")
            
            HelpSection.heading("Performance Issues")
            HelpSection.bulletPoint("Close other memory-intensive apps")
            HelpSection.bulletPoint("Reduce memory limit in AI settings")
            HelpSection.bulletPoint("Clear old memories if needed")
        }
    }
}

// MARK: - Help Section Enum

enum HelpSection: String, CaseIterable, Identifiable {
    case gettingStarted = "Getting Started"
    case writingEntries = "Writing Entries"
    case aiFeatures = "AI Features"
    case privacy = "Privacy & Security"
    case shortcuts = "Keyboard Shortcuts"
    case troubleshooting = "Troubleshooting"
    
    var id: String { rawValue }
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .gettingStarted: return "star"
        case .writingEntries: return "pencil"
        case .aiFeatures: return "sparkles"
        case .privacy: return "lock.shield"
        case .shortcuts: return "keyboard"
        case .troubleshooting: return "wrench.and.screwdriver"
        }
    }
    
    // Helper methods for content
    @MainActor
    static func heading(_ text: String) -> some View {
        Text(text)
            .font(ModernDesignSystem.Typography.headline)
            .fontWeight(.semibold)
            .foregroundStyle(ModernDesignSystem.Colors.textPrimary)
            .padding(.top, ModernDesignSystem.Spacing.sm)
    }
    
    @MainActor
    static func text(_ text: String) -> some View {
        Text(text)
            .font(ModernDesignSystem.Typography.body)
            .foregroundStyle(ModernDesignSystem.Colors.textSecondary)
    }
    
    @MainActor
    static func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.xs) {
            Text("•")
                .font(ModernDesignSystem.Typography.body)
                .foregroundStyle(ModernDesignSystem.Colors.primary)
            
            Text(text)
                .font(ModernDesignSystem.Typography.body)
                .foregroundStyle(ModernDesignSystem.Colors.textPrimary)
        }
        .padding(.leading, ModernDesignSystem.Spacing.sm)
    }
    
    @MainActor
    static func shortcut(_ keys: String, _ description: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ModernDesignSystem.Colors.backgroundSecondary)
                )
            
            Text(description)
                .font(ModernDesignSystem.Typography.body)
                .foregroundStyle(ModernDesignSystem.Colors.textPrimary)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    HelpView()
}