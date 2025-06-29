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
            .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("Secure Setup")
                .font(.system(.headline, design: .default, weight: .medium))
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Invisible button for balance
            Button("Cancel") {
                // No action
            }
            .buttonStyle(.plain)
            .opacity(0)
            .disabled(true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, value: animateContent)
            
            VStack(spacing: 8) {
                Text("Secure Your Diary")
                    .font(.system(.largeTitle, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text("Choose how you'd like to protect your private thoughts and conversations")
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.2), value: animateContent)
    }
    
    private var methodSelectionSection: some View {
        VStack(spacing: 16) {
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
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Create Secure Password")
                    .font(.system(.headline, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                
                VStack(spacing: 16) {
                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(.callout, design: .default, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .frame(height: 32)
                    }
                    
                    // Confirm password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.system(.callout, design: .default, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        SecureField("Confirm password", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                            .frame(height: 32)
                    }
                }
            }
            
            // Password requirements
            VStack(alignment: .leading, spacing: 8) {
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
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
    
    private var setupButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: setupAuthentication) {
                HStack(spacing: 12) {
                    if isSettingUp {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(isSettingUp ? "Setting up..." : "Complete Setup")
                        .font(.system(.body, design: .default, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(canProceed ? .blue : Color(NSColor.disabledControlTextColor))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(!canProceed || isSettingUp)
            .scaleEffect(animateContent ? 1 : 0.9)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: animateContent)
            
            if selectedMethod == .biometric {
                Text("You'll be prompted to authenticate after setup")
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(.secondary)
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
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(isAvailable ? .blue : .secondary)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill((isAvailable ? Color.blue : Color.secondary).opacity(0.1))
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(.body, design: .default, weight: .medium))
                            .foregroundStyle(isAvailable ? .primary : .secondary)
                        
                        if isRecommended {
                            Text("Recommended")
                                .font(.system(.caption, design: .default, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                        
                        if !isAvailable {
                            Text("Not Available")
                                .font(.system(.caption, design: .default, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.2))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(description)
                        .font(.system(.callout, design: .default))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Selection indicator
                if isAvailable {
                    Image(systemName: selectedMethod == method ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(selectedMethod == method ? .blue : .secondary)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .stroke(
                        selectedMethod == method && isAvailable ? Color.blue : Color(NSColor.separatorColor),
                        lineWidth: selectedMethod == method && isAvailable ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
    
    private func passwordRequirement(text: String, isValid: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isValid ? .green : .secondary)
            
            Text(text)
                .font(.system(.caption, design: .default))
                .foregroundStyle(isValid ? .green : .secondary)
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