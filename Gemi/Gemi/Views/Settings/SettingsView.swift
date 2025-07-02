//
//  SettingsView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @Binding var isPresented: Bool
    @State private var selectedCategory: SettingsCategory = .general
    @State private var settingsOffset: CGFloat = 0
    @State private var backdropOpacity: Double = 0
    @State private var isClosing = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SettingsStore.self) private var settings
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Backdrop blur
            if isPresented && !isClosing {
                Color.black
                    .opacity(backdropOpacity * 0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissSettings()
                    }
                    .transition(.opacity)
            }
            
            // Settings panel
            if isPresented && !isClosing {
                settingsPanel
                    .offset(y: settingsOffset)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
        }
        .onAppear {
            showSettings()
        }
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                showSettings()
            } else {
                hideSettings()
            }
        }
    }
    
    // MARK: - Settings Panel
    
    @ViewBuilder
    private var settingsPanel: some View {
        HStack(spacing: 0) {
            // Sidebar navigation
            settingsSidebar
                .frame(width: 220)
            
            Divider()
                .opacity(0.1)
            
            // Content area
            settingsContent
                .frame(width: 580)
        }
        .frame(height: 600)
        .background(settingsPanelBackground)
        .overlay(settingsPanelBorder)
        .shadow(
            color: .black.opacity(0.15),
            radius: 30,
            x: 0,
            y: 20
        )
        .shadow(
            color: .black.opacity(0.08),
            radius: 60,
            x: 0,
            y: 40
        )
    }
    
    @ViewBuilder
    private var settingsPanelBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.regularMaterial)
    }
    
    @ViewBuilder
    private var settingsPanelBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
    }
    
    // MARK: - Sidebar
    
    @ViewBuilder
    private var settingsSidebar: some View {
        VStack(spacing: 0) {
            // Header
            settingsHeader
            
            Divider()
                .opacity(0.1)
            
            // Categories
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(SettingsCategory.allCases) { category in
                        SettingsCategoryButton(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            withAnimation(DesignSystem.Animation.smooth) {
                                selectedCategory = category
                            }
                        }
                    }
                }
                .padding(12)
            }
            
            Spacer()
            
            // Footer actions
            settingsFooter
        }
        .background(Color.primary.opacity(0.02))
    }
    
    @ViewBuilder
    private var settingsHeader: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button {
                dismissSettings()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .tooltip("Close settings (Esc)", edge: .bottom)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    @ViewBuilder
    private var settingsFooter: some View {
        VStack(spacing: 8) {
            Button {
                // Reset to defaults
            } label: {
                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            Divider()
                .opacity(0.1)
            
            // App info
            VStack(spacing: 4) {
                Text("Gemi")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text("Version 1.0.0")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Section header
                sectionHeader
                
                // Section content
                Group {
                    switch selectedCategory {
                    case .general:
                        GeneralSettingsView()
                    case .appearance:
                        AppearanceSettingsView()
                    case .privacy:
                        PrivacySettingsView()
                    case .ai:
                        AISettingsView()
                    case .backup:
                        BackupSettingsView()
                    case .advanced:
                        AdvancedSettingsView()
                    }
                }
                .padding(24)
            }
        }
    }
    
    @ViewBuilder
    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: selectedCategory.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(selectedCategory.color)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedCategory.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text(selectedCategory.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
                .opacity(0.1)
        }
    }
    
    // MARK: - Methods
    
    private func showSettings() {
        withAnimation(DesignSystem.Animation.cozySettle) {
            settingsOffset = 0
            backdropOpacity = 1
        }
    }
    
    private func hideSettings() {
        withAnimation(DesignSystem.Animation.standard) {
            settingsOffset = 50
            backdropOpacity = 0
        }
    }
    
    private func dismissSettings() {
        isClosing = true
        withAnimation(DesignSystem.Animation.standard) {
            isPresented = false
            isClosing = false
        }
    }
    
    private func resetToDefaults() {
        // Reset all user defaults to their initial values
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        UserDefaults.standard.synchronize()
        
        // Show confirmation feedback
        NSSound.beep()
        
        // Reload settings if needed
        selectedCategory = .general
    }
}

// MARK: - Settings Category

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case appearance
    case privacy
    case ai
    case backup
    case advanced
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .privacy: return "Privacy & Security"
        case .ai: return "AI Assistant"
        case .backup: return "Backup & Export"
        case .advanced: return "Advanced"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .appearance: return "paintbrush"
        case .privacy: return "lock.shield"
        case .ai: return "sparkles"
        case .backup: return "arrow.down.doc"
        case .advanced: return "gearshape.2"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .primary
        case .appearance: return .blue
        case .privacy: return .green
        case .ai: return .purple
        case .backup: return .orange
        case .advanced: return .gray
        }
    }
    
    var description: String {
        switch self {
        case .general: return "Basic app preferences"
        case .appearance: return "Customize how Gemi looks"
        case .privacy: return "Keep your data secure"
        case .ai: return "Configure your AI companion"
        case .backup: return "Save and export your journal"
        case .advanced: return "Power user settings"
        }
    }
}

// MARK: - Category Button

struct SettingsCategoryButton: View {
    let category: SettingsCategory
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? .white : category.color)
                    .frame(width: 20)
                
                Text(category.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected ?
                        category.color.gradient :
                        (isHovered ? Color.primary.opacity(0.05) : Color.clear).gradient
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Settings Store

@Observable
class SettingsStore {
    // General
    var autoSaveInterval: TimeInterval = 3.0
    var enableSounds: Bool = true
    var startupBehavior: StartupBehavior = .showTimeline
    
    // Appearance
    var theme: AppTheme = .system
    var accentColor: AppAccentColor = .blue
    var fontSize: FontSize = .medium
    var showLineNumbers: Bool = false
    
    // Privacy
    var requireAuthOnLaunch: Bool = true
    var lockAfterMinutes: Int = 15
    var enableAnalytics: Bool = false
    
    // AI
    var aiModel: String = "gemma-3n"
    var streamResponses: Bool = true
    var memoryLimit: Int = 50
    var contextWindow: Int = 4096
    
    // Backup
    var autoBackup: Bool = true
    var backupFrequency: BackupFrequency = .daily
    var backupLocation: URL?
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        // Load from UserDefaults
    }
    
    func saveSettings() {
        // Save to UserDefaults
    }
    
    func resetToDefaults() {
        // Reset all settings
    }
}


// MARK: - Preview

#Preview {
    @Previewable @State var showSettings = true
    
    SettingsView(isPresented: $showSettings)
        .environment(SettingsStore())
        .frame(width: 1200, height: 800)
        .background(Color(red: 0.96, green: 0.95, blue: 0.94))
}