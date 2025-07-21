import Foundation

/// Manages app settings - simplified without HuggingFace tokens
/// Bundled model doesn't need authentication
@MainActor
class CleanSettingsManager: ObservableObject {
    static let shared = CleanSettingsManager()
    
    // App preferences that are actually needed
    @Published var enableAutoSave = true
    @Published var autoSaveInterval: TimeInterval = 30.0
    @Published var enableSpellCheck = true
    @Published var preferredTheme = "auto" // auto, light, dark
    
    private init() {
        loadPreferences()
    }
    
    private func loadPreferences() {
        // Load from UserDefaults
        enableAutoSave = UserDefaults.standard.bool(forKey: "enableAutoSave")
        autoSaveInterval = UserDefaults.standard.double(forKey: "autoSaveInterval")
        if autoSaveInterval == 0 { autoSaveInterval = 30.0 }
        enableSpellCheck = UserDefaults.standard.bool(forKey: "enableSpellCheck")
        preferredTheme = UserDefaults.standard.string(forKey: "preferredTheme") ?? "auto"
    }
    
    func savePreferences() {
        UserDefaults.standard.set(enableAutoSave, forKey: "enableAutoSave")
        UserDefaults.standard.set(autoSaveInterval, forKey: "autoSaveInterval")
        UserDefaults.standard.set(enableSpellCheck, forKey: "enableSpellCheck")
        UserDefaults.standard.set(preferredTheme, forKey: "preferredTheme")
    }
}