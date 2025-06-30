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
        HStack(spacing: 0) {
            // Left panel - Branding and motivation
            leftBrandingPanel
            
            // Right panel - Authentication
            rightAuthPanel
        }
        .background(DesignSystem.Colors.systemBackground)
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
    
    private var leftBrandingPanel: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                // Elegant icon with subtle animation
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [DesignSystem.Colors.primary.opacity(0.2), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseIcon ? 1.1 : 1.0)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: pulseIcon)
                    
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 60, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(animateContent ? 1.0 : 0.5)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.3), value: animateContent)
                }
                
                VStack(spacing: 16) {
                    Text("Welcome Back")
                        .font(.system(size: 42, weight: .ultraLight, design: .default))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : -30)
                        .animation(.easeOut(duration: 0.8).delay(0.5), value: animateContent)
                    
                    Text("Ready to continue your journey?")
                        .font(.system(size: 18, weight: .light, design: .default))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : -20)
                        .animation(.easeOut(duration: 0.8).delay(0.7), value: animateContent)
                }
                
                // Motivational elements
                VStack(spacing: 14) {
                    motivationalPoint(text: "Your thoughts are waiting")
                    motivationalPoint(text: "AI companion ready to listen")
                    motivationalPoint(text: "Complete privacy guaranteed")
                }
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(0.9), value: animateContent)
            }
            
            Spacer()
            
            // Footer branding
            VStack(spacing: 8) {
                Text("Gemi • Private AI Diary")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                Text("All processing happens on this Mac")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .opacity(animateContent ? 1 : 0)
            .animation(.easeOut(duration: 0.8).delay(1.1), value: animateContent)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.primary.opacity(0.03),
                    DesignSystem.Colors.primary.opacity(0.08),
                    DesignSystem.Colors.primary.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DesignSystem.Colors.separator.opacity(0.5))
                .frame(width: 1)
        }
    }
    
    private var rightAuthPanel: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 48) {
                // Authentication header
                authenticationHeader
                
                // Authentication method
                authenticationSection
                
                // Error display
                if let error = authManager.authenticationError {
                    errorSection(error)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 48)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var authenticationHeader: some View {
        VStack(spacing: 16) {
            Text("Secure Access")
                .font(.system(size: 32, weight: .light, design: .default))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : -20)
                .animation(.easeOut(duration: 0.8).delay(1.3), value: animateContent)
            
            Text("Authenticate to access your private diary")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : -15)
                .animation(.easeOut(duration: 0.8).delay(1.5), value: animateContent)
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
        VStack(spacing: 32) {
            // Biometric icon with modern styling
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primary.opacity(0.1),
                                DesignSystem.Colors.primary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: biometricIcon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(animateContent ? 1.0 : 0.8)
            .opacity(animateContent ? 1 : 0)
            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.7), value: animateContent)
            
            VStack(spacing: 24) {
                Text("Touch \(biometricType) Sensor")
                    .font(.system(size: 20, weight: .medium, design: .default))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.8).delay(1.9), value: animateContent)
                
                if authManager.isAuthenticating {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                            .scaleEffect(1.2)
                        
                        Text("Authenticating...")
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                } else {
                    Button(action: {
                        authenticateWithBiometric()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: biometricIcon)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("Authenticate")
                                .font(.system(size: 16, weight: .semibold, design: .default))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary,
                                    DesignSystem.Colors.primary.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: DesignSystem.Colors.primary.opacity(0.25), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .opacity(animateContent ? 1 : 0)
                    .scaleEffect(animateContent ? 1.0 : 0.9)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(2.1), value: animateContent)
                }
            }
        }
    }
    
    private var passwordAuthSection: some View {
        VStack(spacing: 32) {
            // Password icon with modern styling
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primary.opacity(0.1),
                                DesignSystem.Colors.primary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(animateContent ? 1.0 : 0.8)
            .opacity(animateContent ? 1 : 0)
            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.7), value: animateContent)
            
            VStack(spacing: 24) {
                Text("Enter Your Password")
                    .font(.system(size: 20, weight: .medium, design: .default))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.8).delay(1.9), value: animateContent)
                
                VStack(spacing: 20) {
                    SecureField("Password", text: $password, prompt: Text("Enter your secure password").foregroundColor(DesignSystem.Colors.textTertiary))
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(DesignSystem.Colors.backgroundSecondary)
                                .stroke(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1)
                        )
                        .frame(height: 48)
                        .onSubmit {
                            authenticateWithPassword()
                        }
                        .opacity(animateContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.8).delay(2.1), value: animateContent)
                    
                    if authManager.isAuthenticating {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                                .scaleEffect(1.2)
                            
                            Text("Authenticating...")
                                .font(.system(size: 16, weight: .regular, design: .default))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    } else {
                        Button(action: {
                            authenticateWithPassword()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("Sign In")
                                    .font(.system(size: 16, weight: .semibold, design: .default))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: password.isEmpty ? 
                                        [DesignSystem.Colors.textSecondary.opacity(0.3), DesignSystem.Colors.textSecondary.opacity(0.2)] :
                                        [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: password.isEmpty ? Color.clear : DesignSystem.Colors.primary.opacity(0.25), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .disabled(password.isEmpty)
                        .opacity(animateContent ? 1 : 0)
                        .scaleEffect(animateContent ? 1.0 : 0.9)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(2.3), value: animateContent)
                    }
                }
            }
        }
    }
    
    private func errorSection(_ error: AuthenticationError) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.warning)
                
                Text(error.localizedDescription)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
            // Show alternative method if biometric fails
            if error == .biometricLockout || error == .biometricNotAvailable {
                Button(action: {
                    switchToPasswordAuth()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "key.horizontal")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Use Password Instead")
                            .font(.system(size: 14, weight: .medium, design: .default))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                    )
                    .foregroundStyle(DesignSystem.Colors.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.warning.opacity(0.08))
                .stroke(DesignSystem.Colors.warning.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func motivationalPoint(text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(DesignSystem.Colors.primary.opacity(0.6))
                .frame(width: 6, height: 6)
            
            Text(text)
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            Spacer()
        }
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