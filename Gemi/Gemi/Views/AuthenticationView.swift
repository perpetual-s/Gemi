import SwiftUI
import LocalAuthentication

struct AuthenticationView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var password = ""
    @State private var showingError = false
    @State private var isAuthenticating = false
    @State private var showPassword = false
    @State private var biometricFailed = false
    @State private var shakeAnimation = 0
    @FocusState private var passwordFieldFocused: Bool
    
    // Animation states
    @State private var iconScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0
    @State private var biometricButtonScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background with subtle gradient
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    Color(NSColor.windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                Spacer()
                
                // App branding section
                VStack(spacing: 24) {
                    // Animated app icon
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(Theme.Colors.primaryAccent.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)
                            .scaleEffect(iconScale)
                        
                        // Icon background
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.Colors.primaryAccent,
                                        Theme.Colors.primaryAccent.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: Theme.Colors.primaryAccent.opacity(0.3), radius: 10, y: 5)
                            .scaleEffect(iconScale)
                        
                        // Icon
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                            .scaleEffect(iconScale)
                    }
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            iconScale = 1.0
                        }
                    }
                    
                    // Title and subtitle
                    VStack(spacing: 8) {
                        Text("Welcome to Gemi")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Your private, AI-powered journal")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .opacity(contentOpacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                            contentOpacity = 1.0
                        }
                    }
                }
                
                Spacer()
                    .frame(maxHeight: 40)
                
                // Authentication section
                VStack(spacing: 24) {
                    // Biometric authentication
                    if authManager.isBiometricAvailable && authManager.isBiometricEnabled && !biometricFailed {
                        VStack(spacing: 16) {
                            Button(action: authenticateWithBiometric) {
                                HStack(spacing: 12) {
                                    Image(systemName: biometricIcon)
                                        .font(.system(size: 20))
                                    
                                    Text(biometricButtonTitle)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(width: 280, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Theme.Colors.primaryAccent,
                                                    Theme.Colors.primaryAccent.opacity(0.8)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: Theme.Colors.primaryAccent.opacity(0.3), radius: 8, y: 4)
                                .scaleEffect(biometricButtonScale)
                            }
                            .buttonStyle(.plain)
                            .disabled(isAuthenticating)
                            .onHover { hovering in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    biometricButtonScale = hovering ? 1.05 : 1.0
                                }
                            }
                            
                            HStack(spacing: 16) {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 1)
                                
                                Text("or use password")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 1)
                            }
                            .frame(width: 280)
                        }
                    }
                    
                    // Password authentication
                    VStack(spacing: 16) {
                        // Password field with show/hide toggle
                        HStack(spacing: 0) {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .frame(height: 20)
                            .focused($passwordFieldFocused)
                            .onSubmit {
                                authenticateWithPassword()
                            }
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .frame(width: 280)
                        .modifier(ShakeEffect(animatableData: CGFloat(shakeAnimation)))
                        
                        // Unlock button
                        Button(action: authenticateWithPassword) {
                            HStack {
                                if isAuthenticating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Text("Unlock")
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                            .foregroundColor(password.isEmpty ? .secondary : .white)
                            .frame(width: 280, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(password.isEmpty ? Color.secondary.opacity(0.2) : Theme.Colors.primaryAccent)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(password.isEmpty || isAuthenticating)
                        
                        // Error message (inline)
                        if showingError, let error = authManager.authenticationError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14))
                                
                                Text(errorMessage(for: error))
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.red)
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                }
                .padding(.horizontal, 40)
                .opacity(contentOpacity)
                
                Spacer()
                
                // Footer
                Text("Your journal entries are encrypted and stored locally")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 24)
                    .opacity(contentOpacity)
            }
            .frame(width: 480, height: 640)
        }
        .onAppear {
            passwordFieldFocused = true
            
            // Auto-trigger biometric if available
            if authManager.isBiometricAvailable && authManager.isBiometricEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticateWithBiometric()
                }
            }
        }
        .onChange(of: authManager.authenticationError) { oldError, newError in
            if newError != nil && oldError == nil {
                withAnimation(.default) {
                    showingError = true
                    shakeAnimation += 1
                }
                
                // Auto-hide error after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showingError = false
                    }
                }
            }
        }
    }
    
    private var biometricButtonTitle: String {
        switch authManager.biometricType {
        case .touchID:
            return "Unlock with Touch ID"
        default:
            return "Unlock with Biometrics"
        }
    }
    
    private var biometricIcon: String {
        switch authManager.biometricType {
        case .touchID:
            return "touchid"
        default:
            return "faceid"
        }
    }
    
    private func errorMessage(for error: AuthenticationError) -> String {
        switch error {
        case .incorrectPassword, .invalidPassword:
            return "Incorrect password. Please try again."
        case .biometricFailed:
            return "Authentication failed. Please use your password."
        case .biometricError:
            return "Biometric authentication is not available."
        case .keychainError:
            return "Unable to access secure storage."
        case .passwordRequired:
            return "Password authentication required."
        case .weakPassword:
            return "Password must be at least 6 characters."
        }
    }
    
    private func authenticateWithBiometric() {
        isAuthenticating = true
        
        Task {
            do {
                try await authManager.authenticate()
                isAuthenticating = false
            } catch {
                isAuthenticating = false
                biometricFailed = true
                authManager.authenticationError = error as? AuthenticationError
                passwordFieldFocused = true
            }
        }
    }
    
    private func authenticateWithPassword() {
        guard !password.isEmpty else { return }
        
        isAuthenticating = true
        
        Task {
            do {
                try await authManager.authenticateWithPassword(password)
                isAuthenticating = false
            } catch {
                isAuthenticating = false
                authManager.authenticationError = error as? AuthenticationError
                
                // Clear password and refocus
                await MainActor.run {
                    password = ""
                    passwordFieldFocused = true
                }
            }
        }
    }
}

// Shake animation modifier
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(animatableData * .pi * 2) * 5, y: 0))
    }
}

#Preview {
    AuthenticationView()
}