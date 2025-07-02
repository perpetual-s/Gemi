//
//  AuthenticationFlowPreview.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/28/25.
//

import SwiftUI

/// Preview for testing the complete authentication flow
struct AuthenticationFlowPreview: View {
    
    // MARK: - State
    
    @State private var authManager = AuthenticationManager()
    @State private var journalStore: JournalStore
    
    @State private var selectedScenario: TestScenario = .firstTimeUser
    
    // MARK: - Test Scenarios
    
    enum TestScenario: String, CaseIterable {
        case firstTimeUser = "First Time User"
        case returningUserBiometric = "Returning User (Biometric)"
        case returningUserPassword = "Returning User (Password)"
        case authenticationError = "Authentication Error"
        case sessionExpired = "Session Expired"
        
        var description: String {
            switch self {
            case .firstTimeUser:
                return "Show welcome flow for new users"
            case .returningUserBiometric:
                return "Login with Face ID/Touch ID"
            case .returningUserPassword:
                return "Login with password"
            case .authenticationError:
                return "Handle authentication failures"
            case .sessionExpired:
                return "Session timeout scenario"
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        do {
            let store = try JournalStore()
            self._journalStore = State(initialValue: store)
        } catch {
            // For testing, use a preview store if initialization fails
            print("⚠️ Failed to initialize test journal store: \(error)")
            print("⚠️ Using preview store for testing")
            self._journalStore = State(initialValue: JournalStore.preview)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Test controls
            testControls
            
            // Authentication flow display
            Divider()
            
            MainWindowView()
                .environment(authManager)
                .environment(journalStore)
        }
        .onAppear {
            setupTestScenario()
        }
        .onChange(of: selectedScenario) { _, _ in
            setupTestScenario()
        }
    }
    
    // MARK: - Test Controls
    
    private var testControls: some View {
        VStack(spacing: 16) {
            Text("Authentication Flow Testing")
                .font(.system(.headline, design: .default, weight: .semibold))
                .foregroundStyle(.primary)
            
            // Scenario picker
            Picker("Test Scenario", selection: $selectedScenario) {
                ForEach(TestScenario.allCases, id: \.self) { scenario in
                    VStack(alignment: .leading) {
                        Text(scenario.rawValue)
                            .font(.system(.callout, design: .default, weight: .medium))
                        Text(scenario.description)
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(.secondary)
                    }
                    .tag(scenario)
                }
            }
            .pickerStyle(.menu)
            
            // Current state display
            statusDisplay
            
            // Quick actions
            HStack(spacing: 12) {
                Button("Reset Auth") {
                    resetAuthentication()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Simulate Success") {
                    simulateAuthSuccess()
                }
                .buttonStyle(.bordered)
                
                Button("Simulate Error") {
                    simulateAuthError()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var statusDisplay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Status:")
                    .font(.system(.callout, design: .default, weight: .medium))
                
                Text(authManager.isAuthenticated ? "Authenticated" : "Not Authenticated")
                    .font(.system(.callout, design: .default))
                    .foregroundStyle(authManager.isAuthenticated ? .green : .orange)
            }
            
            HStack {
                Text("Setup:")
                    .font(.system(.callout, design: .default, weight: .medium))
                
                Text(authManager.isFirstTimeSetup ? "First Time" : "Returning User")
                    .font(.system(.callout, design: .default))
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Method:")
                    .font(.system(.callout, design: .default, weight: .medium))
                
                Text(authManager.preferredAuthenticationMethod.displayName)
                    .font(.system(.callout, design: .default))
                    .foregroundStyle(.secondary)
            }
            
            if let error = authManager.authenticationError {
                HStack {
                    Text("Error:")
                        .font(.system(.callout, design: .default, weight: .medium))
                    
                    Text(error.localizedDescription)
                        .font(.system(.callout, design: .default))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor))
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
    
    // MARK: - Test Scenario Setup
    
    private func setupTestScenario() {
        Task { @MainActor in
            // Reset authentication state
            authManager.signOut()
            authManager.authenticationError = nil
            
            // Configure scenario
            switch selectedScenario {
            case .firstTimeUser:
                // Simulate first-time user (clear setup flag)
                UserDefaults.standard.removeObject(forKey: "gemi.auth.hasCompletedSetup")
                
            case .returningUserBiometric:
                // Simulate returning user with biometric preference
                UserDefaults.standard.set(true, forKey: "gemi.auth.hasCompletedSetup")
                UserDefaults.standard.set("biometric", forKey: "gemi.auth.preferredMethod")
                
            case .returningUserPassword:
                // Simulate returning user with password preference
                UserDefaults.standard.set(true, forKey: "gemi.auth.hasCompletedSetup")
                UserDefaults.standard.set("password", forKey: "gemi.auth.preferredMethod")
                
            case .authenticationError:
                // Simulate authentication error
                UserDefaults.standard.set(true, forKey: "gemi.auth.hasCompletedSetup")
                authManager.authenticationError = .biometricLockout
                
            case .sessionExpired:
                // Simulate expired session
                UserDefaults.standard.set(true, forKey: "gemi.auth.hasCompletedSetup")
                // This would be handled by the session timeout logic
            }
            
            print("Test scenario configured: \(selectedScenario.rawValue)")
        }
    }
    
    // MARK: - Test Actions
    
    private func resetAuthentication() {
        Task { @MainActor in
            authManager.signOut()
            authManager.authenticationError = nil
            UserDefaults.standard.removeObject(forKey: "gemi.auth.hasCompletedSetup")
            UserDefaults.standard.removeObject(forKey: "gemi.auth.preferredMethod")
            
            print("Authentication reset to initial state")
        }
    }
    
    private func simulateAuthSuccess() {
        Task { @MainActor in
            // Simulate successful authentication
            let success = await authManager.setupAuthentication(method: .biometric)
            if success {
                print("Simulated authentication success")
            }
        }
    }
    
    private func simulateAuthError() {
        Task { @MainActor in
            authManager.authenticationError = .biometricLockout
            print("Simulated authentication error")
        }
    }
}

// MARK: - Preview

#Preview("Authentication Flow Testing") {
    AuthenticationFlowPreview()
        .frame(width: 900, height: 700)
}

#Preview("Compact Testing") {
    AuthenticationFlowPreview()
        .frame(width: 600, height: 500)
} 