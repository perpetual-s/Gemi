//
//  AuthenticationManager.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/28/25.
//

import Foundation
import LocalAuthentication
import CryptoKit
import Security

/// Authentication method preferences
enum AuthenticationMethod: String, CaseIterable {
    case biometric = "biometric"
    case password = "password"
    
    var displayName: String {
        switch self {
        case .biometric:
            return "Face ID / Touch ID"
        case .password:
            return "Password"
        }
    }
}

/// Authentication errors with user-friendly messages
enum AuthenticationError: LocalizedError {
    case biometricNotAvailable
    case biometricNotEnrolled
    case biometricLockout
    case passwordRequired
    case passwordIncorrect
    case keychainError
    case userCancelled
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this Mac"
        case .biometricNotEnrolled:
            return "No biometric credentials are enrolled. Please set up Face ID or Touch ID in System Preferences"
        case .biometricLockout:
            return "Biometric authentication is temporarily locked due to too many failed attempts"
        case .passwordRequired:
            return "Password authentication is required"
        case .passwordIncorrect:
            return "The password you entered is incorrect"
        case .keychainError:
            return "Unable to access secure storage. Your authentication setup may need to be reset."
        case .userCancelled:
            return "Authentication was cancelled"
        case .unknownError:
            return "An unknown error occurred during authentication"
        }
    }
}

/// Swift 6 Observable Authentication Manager for session-based authentication
@Observable
final class AuthenticationManager {
    
    // MARK: - Published Properties
    
    /// Current authentication state for the session
    var isAuthenticated: Bool = false
    
    /// Whether the app is currently in the authentication process
    var isAuthenticating: Bool = false
    
    /// Current authentication error, if any
    var authenticationError: AuthenticationError?
    
    /// Whether this is the first time setting up authentication
    var isFirstTimeSetup: Bool {
        !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasCompletedSetup)
    }
    
    /// Available biometric type on this device
    var availableBiometricType: LABiometryType {
        let typeContext = LAContext()
        return typeContext.biometryType
    }
    
    /// User's preferred authentication method
    var preferredAuthenticationMethod: AuthenticationMethod {
        get {
            let rawValue = UserDefaults.standard.string(forKey: UserDefaultsKeys.preferredAuthMethod) ?? AuthenticationMethod.biometric.rawValue
            return AuthenticationMethod(rawValue: rawValue) ?? .biometric
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKeys.preferredAuthMethod)
        }
    }
    
    // MARK: - Private Properties
    
    private let keychain = KeychainManager()
    private var sessionStartTime: Date?
    private let sessionTimeoutInterval: TimeInterval = 12 * 60 * 60 // 12 hours
    
    // MARK: - Constants
    
    private struct UserDefaultsKeys {
        static let hasCompletedSetup = "gemi.auth.hasCompletedSetup"
        static let preferredAuthMethod = "gemi.auth.preferredMethod"
        static let lastAuthenticationTime = "gemi.auth.lastAuthTime"
    }
    
    private struct KeychainKeys {
        static let passwordHash = "gemi.auth.passwordHash"
    }
    
    // MARK: - Initialization
    
    init() {
        // Check if we have a valid session from previous app launch
        checkExistingSession()
        
        // Debug: Print current state
        print("AuthenticationManager initialized:")
        print("- isFirstTimeSetup: \(isFirstTimeSetup)")
        print("- preferredAuthenticationMethod: \(preferredAuthenticationMethod)")
        print("- biometric availability: \(checkBiometricAvailability())")
    }
    
    // MARK: - Public Authentication Methods
    
    /// Check if biometric authentication is available and configured
    func checkBiometricAvailability() -> (available: Bool, error: AuthenticationError?) {
        var error: NSError?
        let checkContext = LAContext()
        let available = checkContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        guard available else {
            if let nsError = error {
                switch nsError.code {
                case LAError.biometryNotAvailable.rawValue:
                    return (false, .biometricNotAvailable)
                case LAError.biometryNotEnrolled.rawValue:
                    return (false, .biometricNotEnrolled)
                case LAError.biometryLockout.rawValue:
                    return (false, .biometricLockout)
                default:
                    return (false, .biometricNotAvailable)
                }
            }
            return (false, .biometricNotAvailable)
        }
        
        return (true, nil)
    }
    
    /// Authenticate using the preferred method
    @MainActor
    func authenticate() async -> Bool {
        guard !isAuthenticated else { return true }
        
        isAuthenticating = true
        authenticationError = nil
        
        defer {
            isAuthenticating = false
        }
        
        let success: Bool
        
        switch preferredAuthenticationMethod {
        case .biometric:
            success = await authenticateWithBiometrics()
        case .password:
            // Password authentication will be handled by the UI
            // This method indicates that password is required
            authenticationError = .passwordRequired
            return false
        }
        
        if success {
            completeAuthentication()
        }
        
        return success
    }
    
    /// Authenticate with biometric (Face ID/Touch ID)
    @MainActor
    func authenticateWithBiometrics() async -> Bool {
        let (available, error) = checkBiometricAvailability()
        
        guard available else {
            authenticationError = error
            return false
        }
        
        do {
            let reason = "Authenticate to access your private diary"
            // Create a new context for this authentication to avoid concurrency issues
            let authContext = LAContext()
            let success = try await authContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            
            if success {
                return true
            } else {
                authenticationError = .unknownError
                return false
            }
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel:
                authenticationError = .userCancelled
            case .biometryLockout:
                authenticationError = .biometricLockout
            case .biometryNotAvailable:
                authenticationError = .biometricNotAvailable
            case .biometryNotEnrolled:
                authenticationError = .biometricNotEnrolled
            default:
                authenticationError = .unknownError
            }
            return false
        } catch {
            authenticationError = .unknownError
            return false
        }
    }
    
    /// Authenticate with password
    @MainActor
    func authenticateWithPassword(_ password: String) async -> Bool {
        guard !password.isEmpty else {
            authenticationError = .passwordIncorrect
            return false
        }
        
        isAuthenticating = true
        authenticationError = nil
        
        defer {
            isAuthenticating = false
        }
        
        // Check if we have completed setup and have a password hash stored
        guard !isFirstTimeSetup else {
            print("Authentication error: Setup not completed")
            authenticationError = .keychainError
            return false
        }
        
        // Verify password against stored hash
        do {
            let storedHash = try keychain.retrieveData(for: KeychainKeys.passwordHash)
            let inputHash = hashPassword(password)
            
            guard inputHash == storedHash else {
                print("Authentication error: Password mismatch")
                authenticationError = .passwordIncorrect
                return false
            }
            
            completeAuthentication()
            return true
            
        } catch {
            print("Authentication error: Keychain retrieval failed - \(error)")
            authenticationError = .keychainError
            return false
        }
    }
    
    /// Set up authentication for the first time
    @MainActor
    func setupAuthentication(method: AuthenticationMethod, password: String? = nil) async -> Bool {
        isAuthenticating = true
        authenticationError = nil
        
        defer {
            isAuthenticating = false
        }
        
        // Store preferred method
        preferredAuthenticationMethod = method
        
        // If password method, store the password hash
        if method == .password, let password = password, !password.isEmpty {
            let passwordHash = hashPassword(password)
            
            do {
                try keychain.storeData(passwordHash, for: KeychainKeys.passwordHash)
                print("Successfully stored password hash during setup")
            } catch {
                print("Failed to store password hash during setup: \(error)")
                authenticationError = .keychainError
                return false
            }
        }
        
        // Mark setup as complete
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedSetup)
        
        // Complete authentication for this session
        completeAuthentication()
        
        return true
    }
    
    /// Sign out and require re-authentication
    func signOut() {
        isAuthenticated = false
        sessionStartTime = nil
        authenticationError = nil
    }
    
    /// Reset authentication setup (for troubleshooting)
    func resetAuthenticationSetup() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hasCompletedSetup)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.preferredAuthMethod)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastAuthenticationTime)
        
        // Try to delete stored password hash
        try? keychain.deleteData(for: KeychainKeys.passwordHash)
        
        // Reset state
        isAuthenticated = false
        sessionStartTime = nil
        authenticationError = nil
        
        print("Authentication setup has been reset")
    }
    
    /// Check if the current session is still valid
    func isSessionValid() -> Bool {
        guard isAuthenticated, let sessionStart = sessionStartTime else {
            return false
        }
        
        let elapsed = Date().timeIntervalSince(sessionStart)
        return elapsed < sessionTimeoutInterval
    }
    
    // MARK: - Private Methods
    
    private func completeAuthentication() {
        isAuthenticated = true
        sessionStartTime = Date()
        authenticationError = nil
        
        // Store last authentication time
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.lastAuthenticationTime)
        
        print("Authentication successful - session established")
    }
    
    private func checkExistingSession() {
        // For session-based auth, we don't maintain authentication across app launches
        // Each app launch requires fresh authentication
        isAuthenticated = false
        sessionStartTime = nil
    }
    
    private func hashPassword(_ password: String) -> Data {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash)
    }
}

// MARK: - Keychain Manager

private class KeychainManager {
    
    func storeData(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item first
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            print("Keychain delete warning: \(deleteStatus)")
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            print("Keychain store error: \(status)")
            throw AuthenticationError.keychainError
        }
        
        print("Successfully stored data in keychain for key: \(key)")
    }
    
    func retrieveData(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                print("Keychain error: Item not found for key: \(key)")
            } else {
                print("Keychain retrieve error: \(status) for key: \(key)")
            }
            throw AuthenticationError.keychainError
        }
        
        guard let data = result as? Data else {
            print("Keychain error: Retrieved data is not valid for key: \(key)")
            throw AuthenticationError.keychainError
        }
        
        print("Successfully retrieved data from keychain for key: \(key)")
        return data
    }
    
    func deleteData(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthenticationError.keychainError
        }
    }
} 