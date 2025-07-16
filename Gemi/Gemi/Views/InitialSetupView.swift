import SwiftUI

struct InitialSetupView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var enableBiometric = true
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSettingUp = false
    @FocusState private var passwordFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Beautiful gradient background matching onboarding
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header with animated icon
                VStack(spacing: 32) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 160, height: 160)
                            .blur(radius: 30)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.blue.opacity(0.5), radius: 20)
                    }
                    
                    VStack(spacing: 16) {
                        Text("Secure Your Journal")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Create a password to protect your thoughts")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Password fields with beautiful styling
                VStack(spacing: 16) {
                    OnboardingPasswordField(
                        placeholder: "Password",
                        text: $password,
                        showPasswordToggle: true,
                        validationIcon: password.count >= 6 ? "checkmark.circle.fill" : nil,
                        validationColor: password.count >= 6 ? .green : nil
                    )
                    .focused($passwordFieldFocused)
                    
                    OnboardingPasswordField(
                        placeholder: "Confirm Password",
                        text: $confirmPassword,
                        showPasswordToggle: true,
                        validationIcon: !confirmPassword.isEmpty && password == confirmPassword ? "checkmark.circle.fill" : nil,
                        validationColor: !confirmPassword.isEmpty && password == confirmPassword ? .green : nil
                    )
                    
                    // Password requirements with animation
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: password.count >= 6 ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(password.count >= 6 ? .green : .white.opacity(0.5))
                                .font(.system(size: 14))
                                .animation(.spring(response: 0.3), value: password.count >= 6)
                            Text("At least 6 characters")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if !confirmPassword.isEmpty && password != confirmPassword {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red.opacity(0.8))
                                    .font(.system(size: 14))
                                Text("Passwords don't match")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    // Biometric toggle
                    if authManager.isBiometricAvailable {
                        Toggle(isOn: $enableBiometric) {
                            HStack {
                                Image(systemName: "touchid")
                                    .font(.system(size: 18))
                                Text("Enable \(biometricName)")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: 400)
                
                // Action button
                OnboardingButton(
                    "Complete Setup",
                    icon: "checkmark.shield.fill",
                    isLoading: isSettingUp,
                    action: completeSetup
                )
                .disabled(!isValidSetup || isSettingUp)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
        }
        .frame(width: 700, height: 800)
        .onAppear {
            passwordFieldFocused = true
        }
        .alert("Setup Error", isPresented: $showingError) {
            Button("OK") {
                passwordFieldFocused = true
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // Password validation computed properties
    private var passwordHasLength: Bool {
        password.count >= 6
    }
    
    
    private var isPasswordValid: Bool {
        passwordHasLength
    }
    
    private var biometricName: String {
        switch authManager.biometricType {
        case .touchID:
            return "Touch ID"
        default:
            return "Biometric Authentication"
        }
    }
    
    private var isValidSetup: Bool {
        isPasswordValid && password == confirmPassword
    }
    
    private func completeSetup() {
        guard isValidSetup else { return }
        
        isSettingUp = true
        Task {
            do {
                try await authManager.setupInitialAuthentication(
                    password: password,
                    enableBiometric: enableBiometric
                )
            } catch {
                await MainActor.run {
                    isSettingUp = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
}