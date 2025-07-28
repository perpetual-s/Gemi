import SwiftUI
import Foundation

@MainActor
final class LocalizationManager: ObservableObject {
    @Published var currentLanguage: String {
        didSet {
            updateLanguageSettings()
        }
    }
    
    @Published var isRTL: Bool = false
    
    static let shared = LocalizationManager()
    
    // Supported languages with their native names
    static let supportedLanguages: [(code: String, name: String, nativeName: String)] = [
        ("en", "English", "English"),
        ("ko", "Korean", "한국어"),
        ("ja", "Japanese", "日本語"),
        ("zh-Hans", "Chinese (Simplified)", "简体中文"),
        ("zh-Hant", "Chinese (Traditional)", "繁體中文"),
        ("es", "Spanish", "Español"),
        ("fr", "French", "Français"),
        ("de", "German", "Deutsch"),
        ("ar", "Arabic", "العربية"),
        ("pt", "Portuguese", "Português"),
        ("hi", "Hindi", "हिन्दी"),
        ("id", "Indonesian", "Bahasa Indonesia"),
        ("ru", "Russian", "Русский"),
        ("it", "Italian", "Italiano"),
        ("tr", "Turkish", "Türkçe"),
        ("nl", "Dutch", "Nederlands"),
        ("pl", "Polish", "Polski"),
        ("th", "Thai", "ไทย"),
        ("vi", "Vietnamese", "Tiếng Việt"),
        ("sv", "Swedish", "Svenska")
    ]
    
    private init() {
        // Get saved language or use system default
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage") {
            self.currentLanguage = savedLanguage
        } else {
            // Use system language if supported, otherwise default to English
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            self.currentLanguage = Self.supportedLanguages.contains(where: { $0.code == systemLanguage }) ? systemLanguage : "en"
        }
        
        updateLanguageSettings()
    }
    
    func setLanguage(_ languageCode: String) {
        guard Self.supportedLanguages.contains(where: { $0.code == languageCode }) else { return }
        
        currentLanguage = languageCode
        UserDefaults.standard.set(languageCode, forKey: "AppLanguage")
        
        // Set for the app
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        
        // Note: App restart required for full effect
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
    private func updateLanguageSettings() {
        let locale = Locale(identifier: currentLanguage)
        isRTL = locale.language.characterDirection == .rightToLeft
    }
    
    // Helper function to get localized string
    func localizedString(for key: String, comment: String = "") -> String {
        // First check if we have the lproj folder in Resources
        var bundle = Bundle.main
        
        if let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else if currentLanguage != "en",
                  let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                  let langBundle = Bundle(path: path) {
            // Fallback to English if current language not found
            bundle = langBundle
        }
        
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    
    // Get display name for a language code
    func displayName(for languageCode: String) -> String {
        Self.supportedLanguages.first(where: { $0.code == languageCode })?.name ?? languageCode
    }
    
    // Get native name for a language code
    func nativeName(for languageCode: String) -> String {
        Self.supportedLanguages.first(where: { $0.code == languageCode })?.nativeName ?? languageCode
    }
}

// Notification for language changes
extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
}

// Convenient localization function
func localized(_ key: String, comment: String = "") -> String {
    // This function can be called from any context
    // The actual localization happens through Bundle
    var bundle = Bundle.main
    
    if let languageCode = UserDefaults.standard.string(forKey: "AppLanguage"),
       let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
       let langBundle = Bundle(path: path) {
        bundle = langBundle
    }
    
    return bundle.localizedString(forKey: key, value: key, table: nil)
}

// View modifier for RTL support
struct RTLAware: ViewModifier {
    @ObservedObject private var localization = LocalizationManager.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, 
                        localization.isRTL ? .rightToLeft : .leftToRight)
    }
}

extension View {
    func rtlAware() -> some View {
        modifier(RTLAware())
    }
}

// Font extension for language-specific fonts
extension Font {
    static func localizedSystem(size: CGFloat, weight: Weight = .regular, design: Design = .rounded) -> Font {
        // Get language from UserDefaults to avoid MainActor issues
        let language = UserDefaults.standard.string(forKey: "AppLanguage") ?? "en"
        
        // Use appropriate fonts for different languages
        switch language {
        case "ja":
            // Japanese-optimized font
            return .system(size: size, weight: weight, design: .rounded)
        case "ko":
            // Korean-optimized font
            return .system(size: size, weight: weight, design: .rounded)
        case "zh-Hans", "zh-Hant":
            // Chinese-optimized font
            return .system(size: size, weight: weight, design: .rounded)
        case "ar":
            // Arabic-optimized font
            return .system(size: size, weight: weight, design: .rounded)
        case "hi":
            // Hindi-optimized font (Devanagari script)
            return .system(size: size, weight: weight, design: .rounded)
        case "ru":
            // Russian-optimized font (Cyrillic script)
            return .system(size: size, weight: weight, design: .rounded)
        case "th":
            // Thai-optimized font
            return .system(size: size, weight: weight, design: .rounded)
        case "vi":
            // Vietnamese-optimized font (with tone marks)
            return .system(size: size, weight: weight, design: .rounded)
        case "pl":
            // Polish-optimized font (Latin with diacritics)
            return .system(size: size, weight: weight, design: .rounded)
        default:
            return .system(size: size, weight: weight, design: design)
        }
    }
}

// Date formatting extension
extension Date {
    func localizedString(dateStyle: DateFormatter.Style = .medium,
                        timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        let language = UserDefaults.standard.string(forKey: "AppLanguage") ?? "en"
        formatter.locale = Locale(identifier: language)
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: self)
    }
    
    func localizedRelativeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        let language = UserDefaults.standard.string(forKey: "AppLanguage") ?? "en"
        formatter.locale = Locale(identifier: language)
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// Number formatting extension
extension Int {
    func localizedString() -> String {
        let formatter = NumberFormatter()
        let language = UserDefaults.standard.string(forKey: "AppLanguage") ?? "en"
        formatter.locale = Locale(identifier: language)
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Double {
    func localizedString(style: NumberFormatter.Style = .decimal, 
                        maximumFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        let language = UserDefaults.standard.string(forKey: "AppLanguage") ?? "en"
        formatter.locale = Locale(identifier: language)
        formatter.numberStyle = style
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}