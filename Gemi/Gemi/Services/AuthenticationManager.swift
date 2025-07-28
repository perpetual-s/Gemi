import Foundation
import LocalAuthentication
import Security
import Combine
import AppKit

@MainActor
final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published private(set) var isAuthenticating = false
    @Published var authenticationError: AuthenticationError?
    @Published var requiresInitialSetup = false
    
    // MARK: - Private Properties
    private let context = LAContext()
    private let keychainService = "com.gemi.authentication"
    private let passwordKey = "com.gemi.userPassword"
    private let biometricEnabledKey = "com.gemi.biometricEnabled"
    private let securityTimeoutKey = "com.gemi.securityTimeout"
    private let lastAuthenticationKey = "com.gemi.lastAuthentication"
    
    private var authenticationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var cachedPassword: String?
    
    // MARK: - Computed Properties
    var biometricType: LABiometryType {
        context.biometryType
    }
    
    var isBiometricAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    var isBiometricEnabled: Bool {
        UserDefaults.standard.bool(forKey: biometricEnabledKey)
    }
    
    var securityTimeout: TimeInterval {
        UserDefaults.standard.double(forKey: securityTimeoutKey)
    }
    
    // MARK: - Initialization
    private init() {
        checkInitialSetupRequired()
        setupNotificationObservers()
    }
    
    // MARK: - Public Methods
    
    func authenticate(reason: String = "Authenticate to access your journal") async throws {
        guard !isAuthenticated else { return }
        
        isAuthenticating = true
        authenticationError = nil
        
        defer { isAuthenticating = false }
        
        // Check if we're within the security timeout
        if let lastAuth = UserDefaults.standard.object(forKey: lastAuthenticationKey) as? Date,
           securityTimeout > 0,
           Date().timeIntervalSince(lastAuth) < securityTimeout {
            isAuthenticated = true
            startSecurityTimer()
            return
        }
        
        // Try biometric authentication first if enabled
        if isBiometricEnabled && isBiometricAvailable {
            do {
                try await authenticateWithBiometric(reason: reason)
                return
            } catch {
                // Fall back to password if biometric fails
                print("Biometric authentication failed: \(error)")
            }
        }
        
        // Fall back to password authentication
        throw AuthenticationError.passwordRequired
    }
    
    func authenticateWithPassword(_ password: String) async throws {
        guard try verifyPassword(password) else {
            throw AuthenticationError.incorrectPassword
        }
        
        isAuthenticated = true
        updateLastAuthenticationTime()
        startSecurityTimer()
    }
    
    func setupInitialAuthentication(password: String, enableBiometric: Bool) async throws {
        // Validate password
        guard isValidPassword(password) else {
            throw AuthenticationError.weakPassword
        }
        
        // Save password to keychain
        try savePasswordToKeychain(password)
        
        // Enable biometric if requested and available
        if enableBiometric && isBiometricAvailable {
            UserDefaults.standard.set(true, forKey: biometricEnabledKey)
        }
        
        // Mark setup as complete
        UserDefaults.standard.set(false, forKey: "requiresInitialSetup")
        UserDefaults.standard.set(true, forKey: "hasCompletedInitialSetup")
        requiresInitialSetup = false
        
        // Authenticate immediately
        isAuthenticated = true
        updateLastAuthenticationTime()
        startSecurityTimer()
    }
    
    func updatePassword(currentPassword: String, newPassword: String) async throws {
        // Verify current password
        guard try verifyPassword(currentPassword) else {
            throw AuthenticationError.incorrectPassword
        }
        
        // Validate new password
        guard isValidPassword(newPassword) else {
            throw AuthenticationError.weakPassword
        }
        
        // Update password in keychain
        try savePasswordToKeychain(newPassword)
    }
    
    func setBiometricEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: biometricEnabledKey)
    }
    
    func setSecurityTimeout(_ timeout: TimeInterval) {
        UserDefaults.standard.set(timeout, forKey: securityTimeoutKey)
        
        // Restart timer with new timeout
        if isAuthenticated {
            startSecurityTimer()
        }
    }
    
    func logout() {
        isAuthenticated = false
        authenticationTimer?.invalidate()
        authenticationTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func checkInitialSetupRequired() {
        // Check if this is first launch
        if !UserDefaults.standard.bool(forKey: "hasCompletedInitialSetup") {
            requiresInitialSetup = true
            UserDefaults.standard.set(true, forKey: "requiresInitialSetup")
        } else {
            requiresInitialSetup = UserDefaults.standard.bool(forKey: "requiresInitialSetup")
        }
    }
    
    private func authenticateWithBiometric(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                isAuthenticated = true
                updateLastAuthenticationTime()
                startSecurityTimer()
            } else {
                throw AuthenticationError.biometricFailed
            }
        } catch let error as LAError {
            throw AuthenticationError.biometricError(error)
        }
    }
    
    func verifyPassword(_ password: String) throws -> Bool {
        guard let savedPassword = try loadPasswordFromKeychain() else {
            return false
        }
        return password == savedPassword
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        // Simple password validation - just minimum length
        // This is a personal diary app, not a bank
        return password.count >= 6
    }
    
    private func savePasswordToKeychain(_ password: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw AuthenticationError.invalidPassword
        }
        
        // Delete existing password first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: passwordKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new password
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: passwordKey,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthenticationError.keychainError(status)
        }
        
        // Update cache
        cachedPassword = password
    }
    
    private func loadPasswordFromKeychain() throws -> String? {
        // Return cached password if available
        if let cached = cachedPassword {
            return cached
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: passwordKey,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let passwordData = item as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            if status == errSecItemNotFound {
                return nil
            }
            throw AuthenticationError.keychainError(status)
        }
        
        // Cache the password
        cachedPassword = password
        return password
    }
    
    private func updateLastAuthenticationTime() {
        UserDefaults.standard.set(Date(), forKey: lastAuthenticationKey)
    }
    
    private func startSecurityTimer() {
        authenticationTimer?.invalidate()
        
        guard securityTimeout > 0 else { return }
        
        authenticationTimer = Timer.scheduledTimer(withTimeInterval: securityTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.logout()
            }
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for app lifecycle events
        NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)
            .sink { _ in
                if self.securityTimeout > 0 {
                    self.updateLastAuthenticationTime()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { _ in
                if self.isAuthenticated && self.securityTimeout > 0 {
                    // Check if we need to re-authenticate
                    if let lastAuth = UserDefaults.standard.object(forKey: self.lastAuthenticationKey) as? Date,
                       Date().timeIntervalSince(lastAuth) >= self.securityTimeout {
                        self.logout()
                    }
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Authentication Error

enum AuthenticationError: LocalizedError, Equatable {
    case biometricFailed
    case biometricError(LAError)
    case incorrectPassword
    case weakPassword
    case invalidPassword
    case passwordRequired
    case keychainError(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .biometricFailed:
            return "Biometric authentication failed"
        case .biometricError(let error):
            return error.localizedDescription
        case .incorrectPassword:
            return "Incorrect password"
        case .weakPassword:
            return "Password must be at least 6 characters long"
        case .invalidPassword:
            return "Invalid password format"
        case .passwordRequired:
            return "Password authentication required"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        }
    }
}