import Foundation

/// Reads configuration from .env file
@MainActor
final class EnvironmentConfig {
    static let shared = EnvironmentConfig()
    
    private let config: [String: String]
    
    private init() {
        self.config = Self.loadEnvironmentSync()
    }
    
    /// Load environment variables from .env file
    private static func loadEnvironmentSync() -> [String: String] {
        var config: [String: String] = [:]
        
        print("🔍 Looking for .env file...")
        print("📁 Bundle path: \(Bundle.main.bundlePath)")
        print("📁 Resource path: \(Bundle.main.resourcePath ?? "nil")")
        
        // Look for .env file in the app bundle
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil) {
            print("✅ Found .env at: \(envPath)")
            config.merge(loadFromPath(envPath)) { _, new in new }
            
            // Verify token was loaded
            if let token = config["HUGGINGFACE_TOKEN"], !token.isEmpty {
                print("✅ HuggingFace token loaded successfully (first 7 chars: \(String(token.prefix(7)))...)")
            } else {
                print("❌ CRITICAL: .env file found but no HUGGINGFACE_TOKEN!")
            }
        } else {
            print("⚠️ .env not found via Bundle.main.path")
        }
        
        // Also check in the app's resources directory
        let resourcesURL = Bundle.main.resourceURL?.appendingPathComponent(".env")
        if let resourcesURL = resourcesURL, FileManager.default.fileExists(atPath: resourcesURL.path) {
            print("✅ Found .env at: \(resourcesURL.path)")
            config.merge(loadFromPath(resourcesURL.path)) { _, new in new }
        } else {
            print("⚠️ .env not found in Resources directory")
            if let resourcesURL = Bundle.main.resourceURL {
                print("   Resources path: \(resourcesURL.path)")
            }
        }
        
        print("📋 Loaded \(config.count) environment variables")
        
        return config
    }
    
    private static func loadFromPath(_ path: String) -> [String: String] {
        var config: [String: String] = [:]
        
        do {
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            let lines = contents.components(separatedBy: .newlines)
            
            for line in lines {
                // Skip empty lines and comments
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    continue
                }
                
                // Parse KEY=VALUE format
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    
                    // Remove quotes if present
                    let cleanValue = value
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    
                    config[key] = cleanValue
                }
            }
        } catch {
            print("Warning: Could not load .env file from \(path)")
        }
        
        return config
    }
    
    /// Get value for a key
    func getValue(for key: String) -> String? {
        return config[key]
    }
    
    /// Get HuggingFace token from .env
    var huggingFaceToken: String? {
        return getValue(for: "HUGGINGFACE_TOKEN")
    }
}