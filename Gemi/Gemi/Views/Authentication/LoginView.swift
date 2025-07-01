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
        ZStack {
            // Warm coffee shop background
            backgroundGradient
            
            // Main authentication card
            authenticationCard
                .scaleEffect(animateContent ? 1 : 0.95)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: animateContent)
        }
        .onAppear {
            setupView()
        }
        .onChange(of: authManager.authenticationError) { _, error in
            if error != nil {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showError = true
                }
            } else {
                showError = false
            }
        }
    }
    
    // MARK: - View Components
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                DesignSystem.Colors.canvasBackground,
                DesignSystem.Colors.backgroundPrimary,
                DesignSystem.Colors.canvasBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var authenticationCard: some View {
        VStack(spacing: 48) {
            // App icon and title
            appHeader
            
            // Authentication section
            authenticationSection
            
            // Error display
            if let error = authManager.authenticationError {
                errorSection(error)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 1.1).combined(with: .opacity)
                    ))
            }
            
            // Footer
            footerText
        }
        .padding(60)
        .frame(width: 500)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(DesignSystem.Colors.backgroundSecondary)
                .shadow(
                    color: DesignSystem.Colors.shadowMedium,
                    radius: 30,
                    x: 0,
                    y: 15
                )
        )
    }
    
    private var appHeader: some View {
        VStack(spacing: 24) {
            // App icon with warm glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseIcon ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                        value: pulseIcon
                    )
                
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.36, green: 0.61, blue: 0.84),
                                Color(red: 0.42, green: 0.67, blue: 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("Welcome Back")
                    .font(.system(size: 36, weight: .light, design: .serif))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Ready to continue your journey?")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
    }
    
    private var footerText: some View {
        VStack(spacing: 8) {
            Text("Your private AI diary companion")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            Text("Powered by local Gemma 3n • Zero cloud dependency")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }
    
    private var authenticationSection: some View {
        VStack(spacing: 32) {
            if requiresPassword {
                passwordAuthSection
            } else {
                biometricAuthSection
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.8).delay(1.7), value: animateContent)
    }
    
    private var biometricAuthSection: some View {
        VStack(spacing: 24) {
            // Biometric icon with warm styling
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: biometricIcon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }
            
            Text("Use \(biometricType)")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            if authManager.isAuthenticating {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                        .scaleEffect(0.8)
                    
                    Text("Authenticating...")
                        .font(.system(size: 15))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .padding(.vertical, 12)
            } else {
                Button(action: authenticateWithBiometric) {
                    Text("Authenticate with \(biometricType)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            DesignSystem.Colors.primary,
                                            DesignSystem.Colors.primary.opacity(0.85)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(
                            color: DesignSystem.Colors.primary.opacity(0.3),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var passwordAuthSection: some View {
        VStack(spacing: 24) {
            // Password icon with warm styling
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }
            
            Text("Enter Your Password")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            VStack(spacing: 16) {
                SecureField("Enter your secure password", text: $password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(DesignSystem.Colors.backgroundTertiary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(DesignSystem.Colors.divider, lineWidth: 1)
                            )
                    )
                    .onSubmit(authenticateWithPassword)
                
                if authManager.isAuthenticating {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                            .scaleEffect(0.8)
                        
                        Text("Authenticating...")
                            .font(.system(size: 15))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, 12)
                } else {
                    Button(action: authenticateWithPassword) {
                        Text("Sign In")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: password.isEmpty ?
                                                [DesignSystem.Colors.textTertiary, DesignSystem.Colors.textTertiary] :
                                                [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.85)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(
                                color: password.isEmpty ? Color.clear : DesignSystem.Colors.primary.opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(password.isEmpty)
                }
            }
        }
    }
    
    private func errorSection(_ error: AuthenticationError) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignSystem.Colors.warning)
                
                Text(error.localizedDescription)
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
            // Show alternative methods or reset option
            if error == .biometricLockout || error == .biometricNotAvailable {
                Button(action: switchToPasswordAuth) {
                    Text("Use Password Instead")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.primary)
                }
                .buttonStyle(.plain)
            }
            
            if error == .keychainError {
                Button(action: resetAuthentication) {
                    Text("Reset Authentication")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.warning)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.warning.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignSystem.Colors.warning.opacity(0.3), lineWidth: 1)
                )
        )
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
    
    private func resetAuthentication() {
        // Reset authentication setup and clear errors
        authManager.resetAuthenticationSetup()
        // This will cause the view to switch back to WelcomeView due to isFirstTimeSetup becoming true
    }
}

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: DesignSystem.Colors.primary.opacity(0.25), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environment(AuthenticationManager())
        .frame(width: 1000, height: 600)
}