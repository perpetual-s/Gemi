import SwiftUI

/// Settings and state management for Focus Mode
@MainActor
final class FocusModeSettings: ObservableObject {
    static let shared = FocusModeSettings()
    
    // Focus level settings
    enum FocusLevel: String, CaseIterable {
        case none = "None"
        case line = "Line"
        case sentence = "Sentence"
        case paragraph = "Paragraph"
        
        var icon: String {
            switch self {
            case .none: return "rectangle.dashed"
            case .line: return "text.alignleft"
            case .sentence: return "text.quote"
            case .paragraph: return "text.justify"
            }
        }
    }
    
    // Color scheme options
    enum FocusColorScheme: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case sepia = "Sepia"
        case custom = "Custom"
        
        var backgroundColor: Color {
            switch self {
            case .light:
                return Color(red: 0.98, green: 0.98, blue: 0.97)
            case .dark:
                return Color(red: 0.1, green: 0.1, blue: 0.12)
            case .sepia:
                return Color(red: 0.96, green: 0.93, blue: 0.87)
            case .custom:
                return Color.clear // User defined
            }
        }
        
        var textColor: Color {
            switch self {
            case .light, .sepia:
                return Color(red: 0.2, green: 0.2, blue: 0.2)
            case .dark:
                return Color(red: 0.9, green: 0.9, blue: 0.9)
            case .custom:
                return Color.primary
            }
        }
    }
    
    // Visual settings
    @Published var focusLevel: FocusLevel = .sentence
    @Published var typewriterMode: Bool = true
    @Published var fontSize: CGFloat = 22
    @Published var backgroundOpacity: Double = 0.95
    @Published var highlightIntensity: Double = 0.4
    @Published var maxLineWidth: CGFloat = 750
    @Published var colorScheme: FocusColorScheme = .dark
    @Published var blurAmount: CGFloat = 20
    
    // UI visibility settings
    @Published var showProgress: Bool = true
    @Published var showWordCount: Bool = true
    @Published var autoHideUI: Bool = true
    @Published var uiRevealDelay: Double = 0.3
    
    // Writing goals
    @Published var wordGoal: Int = 750
    @Published var timeGoal: Int = 30 // minutes
    
    // Ambient settings
    @Published var ambientSound: String = "none"
    @Published var ambientVolume: Double = 0.3
    @Published var showAmbientVisuals: Bool = true
    
    // Custom colors (for custom scheme)
    @Published var customBackgroundColor = Color.black
    @Published var customTextColor = Color.white
    
    // Session tracking
    @Published var sessionStartTime = Date()
    @Published var sessionWordCount = 0
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Computed Properties
    
    var activeTextOpacity: Double { 1.0 }
    var inactiveTextOpacity: Double { 1.0 - highlightIntensity }
    
    var effectiveBackgroundColor: Color {
        colorScheme == .custom ? customBackgroundColor : colorScheme.backgroundColor
    }
    
    var effectiveTextColor: Color {
        colorScheme == .custom ? customTextColor : colorScheme.textColor
    }
    
    // MARK: - Methods
    
    func startSession() {
        sessionStartTime = Date()
        sessionWordCount = 0
    }
    
    func endSession() {
        // Could save session stats here
    }
    
    func cycleFocusLevel() {
        let allCases = FocusLevel.allCases
        if let currentIndex = allCases.firstIndex(of: focusLevel) {
            let nextIndex = (currentIndex + 1) % allCases.count
            focusLevel = allCases[nextIndex]
        }
    }
    
    // MARK: - Persistence
    
    private func loadSettings() {
        // Load from UserDefaults
        if let focusLevelRaw = UserDefaults.standard.string(forKey: "focusMode.focusLevel"),
           let level = FocusLevel(rawValue: focusLevelRaw) {
            focusLevel = level
        }
        
        typewriterMode = UserDefaults.standard.bool(forKey: "focusMode.typewriterMode")
        fontSize = UserDefaults.standard.double(forKey: "focusMode.fontSize")
        if fontSize == 0 { fontSize = 22 }
        
        backgroundOpacity = UserDefaults.standard.double(forKey: "focusMode.backgroundOpacity")
        if backgroundOpacity == 0 { backgroundOpacity = 0.95 }
        
        highlightIntensity = UserDefaults.standard.double(forKey: "focusMode.highlightIntensity")
        if highlightIntensity == 0 { highlightIntensity = 0.4 }
        
        wordGoal = UserDefaults.standard.integer(forKey: "focusMode.wordGoal")
        if wordGoal == 0 { wordGoal = 750 }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(focusLevel.rawValue, forKey: "focusMode.focusLevel")
        UserDefaults.standard.set(typewriterMode, forKey: "focusMode.typewriterMode")
        UserDefaults.standard.set(fontSize, forKey: "focusMode.fontSize")
        UserDefaults.standard.set(backgroundOpacity, forKey: "focusMode.backgroundOpacity")
        UserDefaults.standard.set(highlightIntensity, forKey: "focusMode.highlightIntensity")
        UserDefaults.standard.set(wordGoal, forKey: "focusMode.wordGoal")
    }
}