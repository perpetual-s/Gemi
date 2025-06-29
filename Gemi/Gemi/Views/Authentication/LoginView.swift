//
//  LoginView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/28/25.
//

import SwiftUI

/// Login view for daily authentication
struct LoginView: View {
    
    // MARK: - Environment
    
    @Environment(AuthenticationManager.self) private var authManager
    
    // MARK: - State
    
    @State private var password = ""
    @State private var animateContent = false
    @State private var pulseIcon = false
    @State private var showError = false
    
    // MARK: - Computed Properties
    
    private var biometricType: String {
        switch authManager.availableBiometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Biometric Authentication"
        }
    }
    
    private var biometricIcon: String {
        switch authManager.availableBiometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "touchid"
        }
    }
    
    private var requiresPassword: Bool {
        authManager.preferredAuthenticationMethod == .password ||
        authManager.authenticationError == .passwordRequired
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Main content
            VStack(spacing: 40) {
                // App icon and title
                headerSection
                
                // Authentication method
                authenticationSection
                
                // Error display
                if let error = authManager.authenticationError {
                    errorSection(error)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 48)
            
            Spacer()
            
            // Footer
            footerSection
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            setupView()
        }
        .onChange(of: authManager.authenticationError) { _, error in
            if error != nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showError = true
                }
            } else {
                showError = false
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 24) {
            // App icon
            Image(systemName: "book.closed.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeat(.continuous), value: pulseIcon)
            
            VStack(spacing: 8) {
                Text("Welcome Back")
                    .font(.system(.largeTitle, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text("Authenticate to access your private diary")
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.8).delay(0.2), value: animateContent)
    }
    
    private var authenticationSection: some View {
        VStack(spacing: 24) {
            if requiresPassword {
                passwordAuthSection
            } else {
                biometricAuthSection
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.8).delay(0.4), value: animateContent)
    }
    
    private var biometricAuthSection: some View {
        VStack(spacing: 20) {
            // Biometric icon
            Image(systemName: biometricIcon)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.blue)
                .frame(height: 80)
            
            VStack(spacing: 12) {
                Text("Authenticate with \(biometricType)")
                    .font(.system(.headline, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                
                if authManager.isAuthenticating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                        
                        Text("Authenticating...")
                            .font(.system(.callout, design: .default))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("Authenticate") {
                        authenticateWithBiometric()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }
    
    private var passwordAuthSection: some View {
        VStack(spacing: 20) {
            // Password icon
            Image(systemName: "key.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.blue)
                .frame(height: 80)
            
            VStack(spacing: 16) {
                Text("Enter Your Password")
                    .font(.system(.headline, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                
                VStack(spacing: 12) {
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(height: 32)
                        .onSubmit {
                            authenticateWithPassword()
                        }
                    
                    if authManager.isAuthenticating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                            
                            Text("Authenticating...")
                                .font(.system(.callout, design: .default))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Sign In") {
                            authenticateWithPassword()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(password.isEmpty)
                    }
                }
            }
        }
    }
    
    private func errorSection(_ error: AuthenticationError) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.orange)
                
                Text(error.localizedDescription)
                    .font(.system(.callout, design: .default))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
            // Show alternative method if biometric fails
            if error == .biometricLockout || error == .biometricNotAvailable {
                Button("Use Password Instead") {
                    switchToPasswordAuth()
                }
                .font(.system(.callout, design: .default, weight: .medium))
                .foregroundStyle(.blue)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.orange.opacity(0.1))
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Gemi • Privacy-First AI Diary")
                .font(.system(.caption, design: .default, weight: .medium))
                .foregroundStyle(.secondary)
            
            Text("All data stays on your Mac")
                .font(.system(.caption2, design: .default))
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 32)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.8).delay(0.6), value: animateContent)
    }
    
    // MARK: - Actions
    
    private func setupView() {
        withAnimation(.easeInOut(duration: 0.6)) {
            animateContent = true
        }
        
        // Start pulsing icon
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            pulseIcon = true
        }
        
        // Auto-authenticate with biometric if it's the preferred method
        if !requiresPassword {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                authenticateWithBiometric()
            }
        }
    }
    
    private func authenticateWithBiometric() {
        Task {
            await authManager.authenticate()
        }
    }
    
    private func authenticateWithPassword() {
        guard !password.isEmpty else { return }
        
        Task {
            let success = await authManager.authenticateWithPassword(password)
            if !success {
                password = ""
            }
        }
    }
    
    private func switchToPasswordAuth() {
        // Clear the error and indicate password is required
        Task {
            await MainActor.run {
                authManager.authenticationError = .passwordRequired
            }
        }
    }
}

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environment(AuthenticationManager())
        .frame(width: 600, height: 500)
} 