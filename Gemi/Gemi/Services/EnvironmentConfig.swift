import Foundation

/// Environment configuration service
/// Manages application environment settings
@MainActor
final class EnvironmentConfig {
    static let shared = EnvironmentConfig()
    
    private let config: [String: String]
    
    private init() {
        // Initialize with empty configuration
        self.config = [:]
        print("✅ Environment configuration initialized")
    }
    
    /// Get value for a key (kept for compatibility)
    func getValue(for key: String) -> String? {
        return nil // No environment values needed
    }
    
    /// Get HuggingFace token - not needed for Ollama
    var huggingFaceToken: String? {
        return nil // Ollama handles model management
    }
}