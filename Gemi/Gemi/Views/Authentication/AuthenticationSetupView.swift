//
//  AuthenticationSetupView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/28/25.
//

import SwiftUI
import LocalAuthentication

/// Setup view for configuring authentication method
struct AuthenticationSetupView: View {
    
    // MARK: - Environment
    
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var selectedMethod: AuthenticationMethod = .biometric
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSettingUp = false
    @State private var showPasswordFields = false
    @State private var animateContent = false
    
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
    
    private var canUseBiometric: Bool {
        let (available, _) = authManager.checkBiometricAvailability()
        return available
    }
    
    private var isPasswordValid: Bool {
        password.count >= 8 && password == confirmPassword
    }
    
    private var canProceed: Bool {
        switch selectedMethod {
        case .biometric:
            return canUseBiometric
        case .password:
            return isPasswordValid
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Content
            ScrollView {
                VStack(spacing: 32) {
                    // Title and description
                    titleSection
                    
                    // Authentication method selection
                    methodSelectionSection
                    
                    // Password fields (if password method selected)
                    if showPasswordFields {
                        passwordSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                    
                    // Setup button
                    setupButtonSection
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 32)
                .frame(maxWidth: 500)
            }
            
            Spacer(minLength: 0)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                animateContent = true
            }
            
            // Set default method based on availability
            if !canUseBiometric {
                selectedMethod = .password
                showPasswordFields = true
            }
        }
        .onChange(of: selectedMethod) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                showPasswordFields = (newValue == .password)
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            Spacer()
            
            Text("Secure Setup")
                .font(DesignSystem.Fonts.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            // Invisible button for balance
            Button("Cancel") {
                // No action
            }
            .buttonStyle(.plain)
            .opacity(0)
            .disabled(true)
        }
        .padding(.horizontal, DesignSystem.Spacing.large)
        .padding(.vertical, DesignSystem.Spacing.margin)
        .background(DesignSystem.Colors.background)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: DesignSystem.Spacing.margin) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(DesignSystem.Colors.brand)
                .symbolEffect(.pulse, value: animateContent)
            
            VStack(spacing: DesignSystem.Spacing.internalPadding) {
                Text("Secure Your Diary")
                    .font(DesignSystem.Fonts.display)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Choose how you'd like to protect your private thoughts and conversations")
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.2), value: animateContent)
    }
    
    private var methodSelectionSection: some View {
        VStack(spacing: DesignSystem.Spacing.margin) {
            // Biometric option
            authMethodCard(
                method: .biometric,
                icon: biometricIcon,
                title: biometricType,
                description: "Quick and secure access using your biometric data",
                isRecommended: canUseBiometric,
                isAvailable: canUseBiometric
            )
            
            // Password option
            authMethodCard(
                method: .password,
                icon: "key.fill",
                title: "Password",
                description: "Secure access using a strong password you create",
                isRecommended: false,
                isAvailable: true
            )
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateContent)
    }
    
    private var passwordSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                Text("Create Secure Password")
                    .font(DesignSystem.Fonts.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                VStack(spacing: DesignSystem.Spacing.margin) {
                    // Password field
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.internalPadding) {
                        Text("Password")
                            .font(DesignSystem.Fonts.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .frame(height: 32)
                    }
                    
                    // Confirm password field
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.internalPadding) {
                        Text("Confirm Password")
                            .font(DesignSystem.Fonts.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        SecureField("Confirm password", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                            .frame(height: 32)
                    }
                }
            }
            
            // Password requirements
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.internalPadding) {
                passwordRequirement(
                    text: "At least 8 characters",
                    isValid: password.count >= 8
                )
                
                passwordRequirement(
                    text: "Passwords match",
                    isValid: !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Components.cornerRadius)
                .fill(DesignSystem.Colors.backgroundSecondary)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
    
    private var setupButtonSection: some View {
        VStack(spacing: DesignSystem.Spacing.margin) {
            Button(action: setupAuthentication) {
                HStack(spacing: DesignSystem.Spacing.medium) {
                    if isSettingUp {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(isSettingUp ? "Setting up..." : "Complete Setup")
                        .font(DesignSystem.Fonts.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: DesignSystem.Components.buttonHeight)
                .background(canProceed ? DesignSystem.Colors.brand : Color(NSColor.disabledControlTextColor))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Components.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(!canProceed || isSettingUp)
            .scaleEffect(animateContent ? 1 : 0.9)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: animateContent)
            
            if selectedMethod == .biometric {
                Text("You'll be prompted to authenticate after setup")
                    .font(DesignSystem.Fonts.caption1)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func authMethodCard(
        method: AuthenticationMethod,
        icon: String,
        title: String,
        description: String,
        isRecommended: Bool,
        isAvailable: Bool
    ) -> some View {
        Button(action: {
            if isAvailable {
                selectedMethod = method
            }
        }) {
            HStack(spacing: DesignSystem.Spacing.margin) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(isAvailable ? DesignSystem.Colors.brand : DesignSystem.Colors.textSecondary)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Components.cornerRadius)
                            .fill((isAvailable ? DesignSystem.Colors.brand : DesignSystem.Colors.textSecondary).opacity(0.1))
                    )
                
                // Content
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.internalPadding) {
                    HStack(spacing: DesignSystem.Spacing.internalPadding) {
                        Text(title)
                            .font(DesignSystem.Fonts.headline)
                            .foregroundStyle(isAvailable ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                        
                        if isRecommended {
                            Text("Recommended")
                                .font(DesignSystem.Fonts.caption1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.success.opacity(0.2))
                                .foregroundStyle(DesignSystem.Colors.success)
                                .clipShape(Capsule())
                        }
                        
                        if !isAvailable {
                            Text("Not Available")
                                .font(DesignSystem.Fonts.caption1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.textSecondary.opacity(0.2))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(description)
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Selection indicator
                if isAvailable {
                    Image(systemName: selectedMethod == method ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(selectedMethod == method ? DesignSystem.Colors.brand : DesignSystem.Colors.textSecondary)
                }
            }
            .padding(DesignSystem.Spacing.large)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.cornerRadius)
                    .fill(DesignSystem.Colors.backgroundSecondary)
                    .stroke(
                        selectedMethod == method && isAvailable ? DesignSystem.Colors.brand : Color(NSColor.separatorColor),
                        lineWidth: selectedMethod == method && isAvailable ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
    
    private func passwordRequirement(text: String, isValid: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.internalPadding) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isValid ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary)
            
            Text(text)
                .font(DesignSystem.Fonts.caption1)
                .foregroundStyle(isValid ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary)
        }
    }
    
    // MARK: - Actions
    
    private func setupAuthentication() {
        Task {
            isSettingUp = true
            
            let success = await authManager.setupAuthentication(
                method: selectedMethod,
                password: selectedMethod == .password ? password : nil
            )
            
            isSettingUp = false
            
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AuthenticationSetupView()
        .environment(AuthenticationManager())
        .frame(width: 600, height: 700)
} 