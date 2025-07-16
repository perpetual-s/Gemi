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
    
    /// Retrieve HuggingFace token from .env file or Keychain
    func getHuggingFaceToken() -> String? {
        // First check if we have a token in .env file (for release builds)
        if let envToken = EnvironmentConfig.shared.huggingFaceToken,
           !envToken.isEmpty {
            return envToken
        }
        
        // Otherwise check Keychain for user-provided token
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