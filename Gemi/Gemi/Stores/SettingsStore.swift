//
//  SettingsStore.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/5/25.
//

import SwiftUI

// MARK: - UserDefaults Extension

extension UserDefaults {
    func objectExists(forKey key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

// MARK: - Settings Store

@Observable
public class SettingsStore {
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
    
    public init() {
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