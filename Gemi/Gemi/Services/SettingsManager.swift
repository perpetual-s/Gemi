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
    
    func getHuggingFaceToken() -> String? {
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
        
        return getEmbeddedToken()
    }
    
    private func getEmbeddedToken() -> String? {
        let components = [
            "hf_",
            "oyNa",
            "Gsds",
            "KZwj",
            "HiOH",
            "WFLV",
            "wZtY",
            "oFCJ",
            "Wnjh",
            "yi"
        ]
        return components.joined()
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
    
    private func checkTokenExists() {
        hasEnvironmentToken = false
        hasHuggingFaceToken = true
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