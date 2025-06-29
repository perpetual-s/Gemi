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
        VStack(spacing: DesignSystem.Spacing.large) {
            // App icon
            Image(systemName: "book.closed.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(DesignSystem.Colors.primary)
                .symbolEffect(.pulse, options: .repeat(.continuous), value: pulseIcon)
            
            VStack(spacing: DesignSystem.Spacing.internalPadding) {
                Text("Welcome Back")
                    .font(DesignSystem.Typography.display)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Authenticate to access your private diary")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.8).delay(0.2), value: animateContent)
    }
    
    private var authenticationSection: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
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
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Biometric icon
            Image(systemName: biometricIcon)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(DesignSystem.Colors.primary)
                .frame(height: 80)
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("Authenticate with \(biometricType)")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                if authManager.isAuthenticating {
                    HStack(spacing: DesignSystem.Spacing.internalPadding) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.brand))
                            .scaleEffect(0.8)
                        
                        Text("Authenticating...")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
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
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Password icon
            Image(systemName: "key.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(DesignSystem.Colors.primary)
                .frame(height: 80)
            
            VStack(spacing: DesignSystem.Spacing.margin) {
                Text("Enter Your Password")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                VStack(spacing: DesignSystem.Spacing.medium) {
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(height: 32)
                        .onSubmit {
                            authenticateWithPassword()
                        }
                    
                    if authManager.isAuthenticating {
                        HStack(spacing: DesignSystem.Spacing.internalPadding) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.brand))
                                .scaleEffect(0.8)
                            
                            Text("Authenticating...")
                                .font(DesignSystem.Fonts.body)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
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
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.warning)
                
                Text(error.localizedDescription)
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
            // Show alternative method if biometric fails
            if error == .biometricLockout || error == .biometricNotAvailable {
                Button("Use Password Instead") {
                    switchToPasswordAuth()
                }
                .font(DesignSystem.Fonts.body)
                .foregroundStyle(DesignSystem.Colors.brand)
            }
        }
        .padding(DesignSystem.Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusBase)
                .fill(DesignSystem.Colors.warning.opacity(0.1))
                .stroke(DesignSystem.Colors.warning.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var footerSection: some View {
        VStack(spacing: DesignSystem.Spacing.internalPadding) {
            Text("Gemi • Privacy-First AI Diary")
                .font(DesignSystem.Fonts.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            Text("All data stays on your Mac")
                .font(DesignSystem.Fonts.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
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