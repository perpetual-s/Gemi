//
//  AuthenticationFailedView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/28/25.
//

import SwiftUI

/// View displayed when authentication fails with recovery options
struct AuthenticationFailedView: View {
    
    // MARK: - Environment
    
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let error: AuthenticationError
    
    // MARK: - State
    
    @State private var animateContent = false
    @State private var showRecoveryOptions = false
    
    // MARK: - Computed Properties
    
    private var errorIcon: String {
        switch error {
        case .biometricLockout, .biometricNotAvailable, .biometricNotEnrolled:
            return "faceid"
        case .passwordIncorrect, .passwordRequired:
            return "key.slash"
        case .keychainError:
            return "externaldrive.badge.exclamationmark"
        case .userCancelled:
            return "hand.raised"
        case .unknownError:
            return "exclamationmark.triangle"
        }
    }
    
    private var errorColor: Color {
        switch error {
        case .userCancelled:
            return .orange
        case .biometricLockout, .passwordIncorrect:
            return .red
        case .biometricNotAvailable, .biometricNotEnrolled, .passwordRequired:
            return .blue
        default:
            return .red
        }
    }
    
    private var primaryActionTitle: String {
        switch error {
        case .biometricLockout, .biometricNotAvailable:
            return "Use Password"
        case .passwordIncorrect:
            return "Try Again"
        case .userCancelled:
            return "Try Again"
        case .biometricNotEnrolled:
            return "Set Up Password"
        default:
            return "Retry"
        }
    }
    
    private var canShowRecoveryOptions: Bool {
        switch error {
        case .biometricLockout, .biometricNotAvailable, .biometricNotEnrolled, .keychainError:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Main content
            VStack(spacing: 32) {
                // Error illustration
                errorIllustration
                
                // Error description
                errorDescription
                
                // Action buttons
                actionButtons
                
                // Recovery options
                if showRecoveryOptions {
                    recoveryOptionsSection
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 48)
            
            Spacer()
            
            // Footer with additional help
            footerSection
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                animateContent = true
            }
        }
    }
    
    // MARK: - View Components
    
    private var errorIllustration: some View {
        VStack(spacing: 20) {
            // Error icon with animation
            Image(systemName: errorIcon)
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(errorColor)
                .symbolEffect(.bounce, value: animateContent)
            
            // Supporting visual elements
            if error == .biometricLockout {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                            .opacity(animateContent ? 1 : 0)
                            .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.1), value: animateContent)
                    }
                }
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.8).delay(0.2), value: animateContent)
    }
    
    private var errorDescription: some View {
        VStack(spacing: 16) {
            Text(errorTitle)
                .font(.system(.title2, design: .default, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            
            Text(error.localizedDescription)
                .font(.system(.body, design: .default))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            
            // Additional helpful text based on error type
            if let helpText = additionalHelpText {
                Text(helpText)
                    .font(.system(.callout, design: .default))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.8).delay(0.4), value: animateContent)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary action button
            Button(action: primaryAction) {
                Text(primaryActionTitle)
                    .font(.system(.body, design: .default, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(errorColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            
            // Secondary actions
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(.callout, design: .default, weight: .medium))
                .foregroundStyle(.secondary)
                
                if canShowRecoveryOptions {
                    Button("More Options") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showRecoveryOptions.toggle()
                        }
                    }
                    .font(.system(.callout, design: .default, weight: .medium))
                    .foregroundStyle(.blue)
                }
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.8).delay(0.6), value: animateContent)
    }
    
    private var recoveryOptionsSection: some View {
        VStack(spacing: 16) {
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Recovery Options")
                    .font(.system(.headline, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                
                VStack(spacing: 8) {
                    if error == .biometricLockout || error == .biometricNotAvailable {
                        recoveryOption(
                            icon: "key.fill",
                            title: "Use Password Authentication",
                            description: "Switch to password-based authentication",
                            action: switchToPassword
                        )
                    }
                    
                    if error == .biometricNotEnrolled {
                        recoveryOption(
                            icon: "gear",
                            title: "Set Up Biometric Authentication",
                            description: "Configure Face ID or Touch ID in System Preferences",
                            action: openSystemPreferences
                        )
                    }
                    
                    if error == .keychainError {
                        recoveryOption(
                            icon: "arrow.clockwise",
                            title: "Reset Authentication",
                            description: "Reset and reconfigure your authentication method",
                            action: resetAuthentication
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Need Help?")
                .font(.system(.caption, design: .default, weight: .medium))
                .foregroundStyle(.secondary)
            
            Button("Contact Support") {
                // This would open support documentation or email
                openSupportDocumentation()
            }
            .font(.system(.caption, design: .default, weight: .medium))
            .foregroundStyle(.blue)
        }
        .padding(.bottom, 32)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.8).delay(0.8), value: animateContent)
    }
    
    // MARK: - Helper Views
    
    private func recoveryOption(
        icon: String,
        title: String,
        description: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.callout, design: .default, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties for Content
    
    private var errorTitle: String {
        switch error {
        case .biometricLockout:
            return "Authentication Locked"
        case .biometricNotAvailable:
            return "Biometric Authentication Unavailable"
        case .biometricNotEnrolled:
            return "Biometric Authentication Not Set Up"
        case .passwordIncorrect:
            return "Incorrect Password"
        case .passwordRequired:
            return "Password Required"
        case .keychainError:
            return "Security Error"
        case .userCancelled:
            return "Authentication Cancelled"
        case .unknownError:
            return "Authentication Failed"
        }
    }
    
    private var additionalHelpText: String? {
        switch error {
        case .biometricLockout:
            return "Try again in a few minutes or use your password"
        case .biometricNotAvailable:
            return "Your Mac doesn't support biometric authentication"
        case .biometricNotEnrolled:
            return "Set up Face ID or Touch ID in System Preferences > Touch ID & Password"
        case .passwordIncorrect:
            return "Make sure you're using the correct password for your diary"
        case .keychainError:
            return "There was a problem accessing secure storage"
        default:
            return nil
        }
    }
    
    // MARK: - Actions
    
    private func primaryAction() {
        switch error {
        case .biometricLockout, .biometricNotAvailable:
            switchToPassword()
        case .passwordIncorrect, .userCancelled:
            dismiss()
        case .biometricNotEnrolled:
            // Offer to set up password instead
            showSetupPassword()
        default:
            dismiss()
        }
    }
    
    private func switchToPassword() {
        Task {
            await MainActor.run {
                authManager.authenticationError = .passwordRequired
                dismiss()
            }
        }
    }
    
    private func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_TouchID")!
        NSWorkspace.shared.open(url)
        dismiss()
    }
    
    private func resetAuthentication() {
        Task {
            await MainActor.run {
                authManager.signOut()
                // This would typically show the setup flow again
                dismiss()
            }
        }
    }
    
    private func showSetupPassword() {
        // This would show the authentication setup with password pre-selected
        dismiss()
    }
    
    private func openSupportDocumentation() {
        // This would open support documentation or help
        // For now, we'll just print to console
        print("Opening support documentation...")
    }
}

// MARK: - Preview

#Preview("Biometric Lockout") {
    AuthenticationFailedView(error: .biometricLockout)
        .environment(AuthenticationManager())
        .frame(width: 600, height: 500)
}

#Preview("Password Incorrect") {
    AuthenticationFailedView(error: .passwordIncorrect)
        .environment(AuthenticationManager())
        .frame(width: 600, height: 500)
}

#Preview("Biometric Not Available") {
    AuthenticationFailedView(error: .biometricNotAvailable)
        .environment(AuthenticationManager())
        .frame(width: 600, height: 500)
} 