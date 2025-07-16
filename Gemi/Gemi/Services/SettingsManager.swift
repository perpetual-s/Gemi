import Foundation
import Security

/// Manages app settings including HuggingFace token
@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var hasHuggingFaceToken: Bool = false
    @Published var hasEnvironmentToken: Bool = false
    
    private let tokenKey = "com.gemi.huggingface.token"
    
    init() {
        checkTokenExists()
    }
    
    /// Store HuggingFace token securely in Keychain
    func saveHuggingFaceToken(_ token: String) throws {
        let tokenData = token.data(using: .utf8)!
        
        // Delete existing token if any
        deleteHuggingFaceToken()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            hasHuggingFaceToken = true
        } else {
            throw SettingsError.keychainError(status)
        }
    }
    
    /// Retrieve HuggingFace token - uses embedded token for zero-friction experience
    func getHuggingFaceToken() -> String? {
        // First check .env file for the token
        if let envToken = EnvironmentConfig.shared.huggingFaceToken,
           !envToken.isEmpty {
            return envToken
        }
        
        // For production builds, the token should be in .env file
        // which is NOT committed to git (it's in .gitignore)
        // This provides zero-friction experience without exposing tokens
        
        // Fallback: check Keychain for any user-provided token
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }
        
        return nil
    }
    
    /// Delete HuggingFace token from Keychain
    func deleteHuggingFaceToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey
        ]
        
        SecItemDelete(query as CFDictionary)
        hasHuggingFaceToken = false
    }
    
    /// Check if token exists (either in .env or in Keychain)
    private func checkTokenExists() {
        hasEnvironmentToken = EnvironmentConfig.shared.huggingFaceToken != nil
        hasHuggingFaceToken = getHuggingFaceToken() != nil
    }
}

enum SettingsError: LocalizedError {
    case keychainError(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .keychainError(let status):
            return "Keychain error: \(status)"
        }
    }
}