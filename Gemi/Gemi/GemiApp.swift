//
//  GemiApp.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/28/25.
//

import SwiftUI

@main
struct GemiApp: App {
    
    // MARK: - Dependencies
    
    /// Global authentication manager
    @State private var authenticationManager = AuthenticationManager()
    
    /// Global journal store
    @State private var journalStore: JournalStore = {
        do {
            return try JournalStore()
        } catch {
            fatalError("Failed to initialize JournalStore: \(error)")
        }
    }()
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if authenticationManager.isAuthenticated {
                    // Main application interface
                    MainWindowView()
                        .environment(authenticationManager)
                        .environment(journalStore)
                        .preferredColorScheme(nil) // Respect system appearance
                } else {
                    // Authentication flow
                    AuthenticationFlowView()
                        .environment(authenticationManager)
                }
            }
            .task {
                // Load initial data on app launch
                await journalStore.loadEntries()
                }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        .windowToolbarStyle(.unified)
        .commands {
            GemiCommands()
        }
    }
}

// MARK: - Authentication Flow

/// Handles the authentication flow before accessing the main app
struct AuthenticationFlowView: View {
    @Environment(AuthenticationManager.self) private var authManager
    
    var body: some View {
        Group {
            if authManager.isFirstTimeSetup {
                WelcomeView()
            } else {
                LoginView()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(DesignSystem.Colors.systemBackground)
    }
}

// MARK: - Main Application Interface

/// The main three-pane interface for Gemi
struct MainWindowView: View {
    
    // MARK: - Dependencies
    
    @Environment(JournalStore.self) private var journalStore
    @Environment(AuthenticationManager.self) private var authManager
    
    // MARK: - State
    
    @State private var selectedEntry: JournalEntry?
    @State private var showingCompose = false
    @State private var showingChat = false
    @State private var showingSettings = false
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    
    // MARK: - Body
    
    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            // MARK: Sidebar (240pt)
            SidebarView(
                selectedEntry: $selectedEntry,
                showingCompose: $showingCompose,
                showingChat: $showingChat,
                showingSettings: $showingSettings
            )
            .navigationSplitViewColumnWidth(
                min: DesignSystem.Spacing.sidebarWidth,
                ideal: DesignSystem.Spacing.sidebarWidth,
                max: DesignSystem.Spacing.sidebarWidth
            )
        } content: {
            // MARK: Timeline (300-400pt)
                    TimelineView(selectedEntry: $selectedEntry)
                .navigationSplitViewColumnWidth(
                    min: DesignSystem.Spacing.timelineMinWidth,
                    ideal: DesignSystem.Spacing.timelineWidth,
                    max: DesignSystem.Spacing.timelineMaxWidth
                )
                } detail: {
            // MARK: Detail/Editor (Flexible)
            DetailView(selectedEntry: $selectedEntry)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingChat = true
                } label: {
                    Label("Talk to Gemi", systemImage: "message.circle.fill")
                }
                .help("Start a conversation with your AI companion")
                
                Button {
                    showingCompose = true
                } label: {
                    Label("New Entry", systemImage: "square.and.pencil")
                }
                .help("Create a new journal entry")
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $showingCompose) {
            NavigationStack {
                ComposeView(entry: .constant(nil))
                    .environment(journalStore)
            }
        }
        .sheet(isPresented: $showingChat) {
            NavigationStack {
                ChatView()
                    .environment(journalStore)
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .environment(authManager)
                    .environment(journalStore)
            }
        }
        .task {
            // Load journal entries on app start
            await journalStore.refreshEntries()
        }
    }
}

// MARK: - Sidebar

/// Beautiful sidebar with navigation and quick actions
struct SidebarView: View {
    
    // MARK: - Bindings
    
    @Binding var selectedEntry: JournalEntry?
    @Binding var showingCompose: Bool
    @Binding var showingChat: Bool
    @Binding var showingSettings: Bool
    
    // MARK: - Dependencies
    
    @Environment(JournalStore.self) private var journalStore
    @Environment(AuthenticationManager.self) private var authManager
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app title
            sidebarHeader
            
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.base)
            
            // Navigation content
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.small, pinnedViews: .sectionHeaders) {
                    // Quick Actions Section
                    quickActionsSection
                    
                    // Recent Entries Section
                    recentEntriesSection
                    
                    // Stats Section
                    statsSection
                }
                .padding(.horizontal, DesignSystem.Spacing.base)
                .padding(.vertical, DesignSystem.Spacing.medium)
            }
            
            Spacer()
            
            // Bottom section with settings
            sidebarFooter
        }
        .background(DesignSystem.Colors.systemSecondaryBackground)
        .navigationTitle("")
    }
    
    // MARK: - Header
    
    private var sidebarHeader: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: "book.closed.fill")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.systemAccent)
                
                Text("Gemi")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.base)
            .padding(.top, DesignSystem.Spacing.medium)
            
            Text("Your Private AI Diary")
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.base)
                .padding(.bottom, DesignSystem.Spacing.medium)
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            SectionHeader(title: "Quick Actions")
            
            VStack(spacing: DesignSystem.Spacing.tiny) {
                SidebarButton(
                    icon: "square.and.pencil",
                    title: "New Entry",
                    subtitle: "Start writing",
                    action: { showingCompose = true }
                )
                
                SidebarButton(
                    icon: "message.circle.fill",
                    title: "Talk to Gemi",
                    subtitle: "AI conversation",
                    action: { showingChat = true }
                )
            }
        }
        .gemiSectionSpacing()
    }
    
    // MARK: - Recent Entries
    
    private var recentEntriesSection: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            SectionHeader(title: "Recent Entries")
            
            VStack(spacing: DesignSystem.Spacing.tiny) {
                ForEach(Array(journalStore.entries.prefix(5))) { entry in
                    SidebarEntryRow(
                        entry: entry,
                        isSelected: entry.id == selectedEntry?.id,
                        action: { selectedEntry = entry }
                    )
                }
                
                if journalStore.entries.isEmpty {
                    Text("No entries yet")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignSystem.Spacing.small)
                }
            }
        }
        .gemiSectionSpacing()
    }
    
    // MARK: - Stats
    
    private var statsSection: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            SectionHeader(title: "Journal Stats")
            
            HStack(spacing: DesignSystem.Spacing.medium) {
                StatCard(
                    value: "\(journalStore.entries.count)",
                    label: "Entries"
                )
                
                StatCard(
                    value: "\(journalStore.currentStreak)",
                    label: "Day Streak"
                )
            }
        }
        .gemiSectionSpacing()
    }
    
    // MARK: - Footer
    
    private var sidebarFooter: some View {
        VStack(spacing: DesignSystem.Spacing.tiny) {
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.base)
            
            Button {
                showingSettings = true
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(DesignSystem.Typography.callout)
                    
                    Text("Settings")
                        .font(DesignSystem.Typography.callout)
                    
                    Spacer()
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.base)
                .padding(.vertical, DesignSystem.Spacing.small)
            }
            .buttonStyle(.plain)
            .padding(.bottom, DesignSystem.Spacing.base)
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Spacer()
        }
    }
}

struct SidebarButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.systemAccent)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                    .fill(Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SidebarEntryRow: View {
    let entry: JournalEntry
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entryTitle(for: entry))
                    .font(DesignSystem.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                
                Text(entry.date, style: .date)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.tiny)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                    .fill(isSelected ? DesignSystem.Colors.systemAccent.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    /// Generate a title from the entry's content
    private func entryTitle(for entry: JournalEntry) -> String {
        let trimmed = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "Untitled Entry"
        }
        
        // Take the first line or first 50 characters, whichever is shorter
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? ""
        let title = String(firstLine.prefix(50))
        
        return title.isEmpty ? "Untitled Entry" : title
    }
}

struct StatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DesignSystem.Typography.headline)
                .fontWeight(.bold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                .fill(DesignSystem.Colors.systemTertiaryBackground)
        )
    }
}

// MARK: - Detail View

/// The detail/editor pane that shows selected entry or compose interface
struct DetailView: View {
    @Binding var selectedEntry: JournalEntry?
    
    var body: some View {
        Group {
            if let entry = selectedEntry {
                // Show selected entry in read/edit mode
                ComposeView(entry: .constant(entry))
            } else {
                // Empty state
                VStack(spacing: DesignSystem.Spacing.large) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 64))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    
                    VStack(spacing: DesignSystem.Spacing.small) {
                        Text("Select an Entry")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        
                        Text("Choose an entry from the timeline to read or edit")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignSystem.Colors.systemBackground)
            }
        }
    }
}

// MARK: - Placeholder Views

struct ChatView: View {
    var body: some View {
        VStack {
            Text("Chat with Gemi")
                .font(DesignSystem.Typography.title2)
            Text("Coming soon...")
                .font(DesignSystem.Typography.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Talk to Gemi")
    }
}

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .font(DesignSystem.Typography.title2)
            Text("Coming soon...")
                .font(DesignSystem.Typography.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
    }
}

// MARK: - Menu Commands

struct GemiCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Entry") {
                // Handle new entry command
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Button("Talk to Gemi") {
                // Handle chat command
            }
            .keyboardShortcut("t", modifiers: .command)
        }
    }
}
