import Foundation

/// Environment configuration service
/// NOTE: .env files are no longer needed for mlx-community models
@MainActor
final class EnvironmentConfig {
    static let shared = EnvironmentConfig()
    
    private let config: [String: String]
    
    private init() {
        // No longer load .env files - mlx-community models don't need authentication
        self.config = [:]
        print("✅ Using mlx-community models - no authentication required")
    }
    
    /// Get value for a key (kept for compatibility)
    func getValue(for key: String) -> String? {
        return nil // No environment values needed
    }
    
    /// Get HuggingFace token - always returns nil for mlx-community models
    var huggingFaceToken: String? {
        return nil // mlx-community models don't need tokens
    }
}