//
//  SettingsView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

// MARK: - UserDefaults Extension

extension UserDefaults {
    func objectExists(forKey key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

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
                settings.resetToDefaults()
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
        // This method is no longer needed as we're using settings.resetToDefaults()
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
    // Flag to prevent saving during bulk updates
    private var isLoadingSettings = false
    
    // General
    var autoSaveInterval: TimeInterval = 3.0 {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    var enableSounds: Bool = true {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    var startupBehavior: StartupBehavior = .showTimeline {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    
    // Appearance
    var theme: AppTheme = .system {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    var accentColor: AppAccentColor = .blue {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    var fontSize: FontSize = .medium {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    var showLineNumbers: Bool = false {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    
    // Privacy
    var requireAuthOnLaunch: Bool = true {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    var lockAfterMinutes: Int = 15 {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    var enableAnalytics: Bool = false {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    
    // AI
    var aiModel: String = "gemma-3n" {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    var streamResponses: Bool = true {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    var memoryLimit: Int = 50 {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    var contextWindow: Int = 4096 {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    
    // Backup
    var autoBackup: Bool = true {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    var backupFrequency: BackupFrequency = .daily {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    var backupLocation: URL? {
        didSet { if !isLoadingSettings { saveSettings() } }
    }
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }
        
        let defaults = UserDefaults.standard
        
        // General settings
        autoSaveInterval = defaults.double(forKey: "autoSaveInterval")
        if autoSaveInterval == 0 { autoSaveInterval = 3.0 } // Default value if not set
        
        enableSounds = defaults.bool(forKey: "enableSounds")
        if !defaults.objectExists(forKey: "enableSounds") { enableSounds = true }
        
        if let startupBehaviorRaw = defaults.string(forKey: "startupBehavior"),
           let behavior = StartupBehavior(rawValue: startupBehaviorRaw) {
            startupBehavior = behavior
        }
        
        // Appearance settings
        if let themeRaw = defaults.string(forKey: "theme"),
           let themeValue = AppTheme(rawValue: themeRaw) {
            theme = themeValue
        }
        
        if let accentColorRaw = defaults.string(forKey: "accentColor"),
           let colorValue = AppAccentColor(rawValue: accentColorRaw) {
            accentColor = colorValue
        }
        
        if let fontSizeRaw = defaults.string(forKey: "fontSize"),
           let sizeValue = FontSize(rawValue: fontSizeRaw) {
            fontSize = sizeValue
        }
        
        showLineNumbers = defaults.bool(forKey: "showLineNumbers")
        
        // Privacy settings
        requireAuthOnLaunch = defaults.bool(forKey: "requireAuthOnLaunch")
        if !defaults.objectExists(forKey: "requireAuthOnLaunch") { requireAuthOnLaunch = true }
        
        lockAfterMinutes = defaults.integer(forKey: "lockAfterMinutes")
        if lockAfterMinutes == 0 { lockAfterMinutes = 15 } // Default value if not set
        
        enableAnalytics = defaults.bool(forKey: "enableAnalytics")
        
        // AI settings
        if let model = defaults.string(forKey: "aiModel") {
            aiModel = model
        }
        
        streamResponses = defaults.bool(forKey: "streamResponses")
        if !defaults.objectExists(forKey: "streamResponses") { streamResponses = true }
        
        memoryLimit = defaults.integer(forKey: "memoryLimit")
        if memoryLimit == 0 { memoryLimit = 50 } // Default value if not set
        
        contextWindow = defaults.integer(forKey: "contextWindow")
        if contextWindow == 0 { contextWindow = 4096 } // Default value if not set
        
        // Backup settings
        autoBackup = defaults.bool(forKey: "autoBackup")
        if !defaults.objectExists(forKey: "autoBackup") { autoBackup = true }
        
        if let backupFrequencyRaw = defaults.string(forKey: "backupFrequency"),
           let frequency = BackupFrequency(rawValue: backupFrequencyRaw) {
            backupFrequency = frequency
        }
        
        if let bookmarkData = defaults.data(forKey: "backupLocationBookmark") {
            do {
                var isStale = false
                backupLocation = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale {
                    // Re-create the bookmark if it's stale
                    backupLocation = nil
                }
            } catch {
                print("Failed to resolve backup location bookmark: \(error)")
                backupLocation = nil
            }
        }
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        
        // General settings
        defaults.set(autoSaveInterval, forKey: "autoSaveInterval")
        defaults.set(enableSounds, forKey: "enableSounds")
        defaults.set(startupBehavior.rawValue, forKey: "startupBehavior")
        
        // Appearance settings
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(accentColor.rawValue, forKey: "accentColor")
        defaults.set(fontSize.rawValue, forKey: "fontSize")
        defaults.set(showLineNumbers, forKey: "showLineNumbers")
        
        // Privacy settings
        defaults.set(requireAuthOnLaunch, forKey: "requireAuthOnLaunch")
        defaults.set(lockAfterMinutes, forKey: "lockAfterMinutes")
        defaults.set(enableAnalytics, forKey: "enableAnalytics")
        
        // AI settings
        defaults.set(aiModel, forKey: "aiModel")
        defaults.set(streamResponses, forKey: "streamResponses")
        defaults.set(memoryLimit, forKey: "memoryLimit")
        defaults.set(contextWindow, forKey: "contextWindow")
        
        // Backup settings
        defaults.set(autoBackup, forKey: "autoBackup")
        defaults.set(backupFrequency.rawValue, forKey: "backupFrequency")
        
        // Save backup location as bookmark for sandbox security
        if let url = backupLocation {
            do {
                let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                defaults.set(bookmarkData, forKey: "backupLocationBookmark")
            } catch {
                print("Failed to create backup location bookmark: \(error)")
            }
        } else {
            defaults.removeObject(forKey: "backupLocationBookmark")
        }
        
        // Synchronize to ensure immediate persistence
        defaults.synchronize()
    }
    
    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }
        
        // Reset all settings to default values
        autoSaveInterval = 3.0
        enableSounds = true
        startupBehavior = .showTimeline
        
        theme = .system
        accentColor = .blue
        fontSize = .medium
        showLineNumbers = false
        
        requireAuthOnLaunch = true
        lockAfterMinutes = 15
        enableAnalytics = false
        
        aiModel = "gemma-3n"
        streamResponses = true
        memoryLimit = 50
        contextWindow = 4096
        
        autoBackup = true
        backupFrequency = .daily
        backupLocation = nil
        
        // Clear only settings-related UserDefaults keys
        let defaults = UserDefaults.standard
        let settingsKeys = [
            "autoSaveInterval", "enableSounds", "startupBehavior",
            "theme", "accentColor", "fontSize", "showLineNumbers",
            "requireAuthOnLaunch", "lockAfterMinutes", "enableAnalytics",
            "aiModel", "streamResponses", "memoryLimit", "contextWindow",
            "autoBackup", "backupFrequency", "backupLocationBookmark"
        ]
        
        for key in settingsKeys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        
        // Manually save after resetting
        saveSettings()
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