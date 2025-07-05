import SwiftUI

struct InitialSetupView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var enableBiometric = true
    @State private var showingError = false
    @State private var errorMessage = ""
    @FocusState private var passwordFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Theme.Colors.primaryAccent)
                
                Text("Secure Your Journal")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                
                Text("Set up authentication to protect your private thoughts")
                    .font(.title3)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 48)
            
            // Setup form
            VStack(alignment: .leading, spacing: 24) {
                // Password fields
                VStack(alignment: .leading, spacing: 12) {
                    Text("Create Password")
                        .font(.headline)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .focused($passwordFieldFocused)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Password must be at least 8 characters")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                // Biometric option
                if authManager.isBiometricAvailable {
                    Toggle(isOn: $enableBiometric) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable \(biometricName)")
                                .font(.headline)
                            Text("Use biometric authentication for quick access")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                
                // Action buttons
                HStack {
                    Spacer()
                    
                    Button("Set Up Later") {
                        skipSetup()
                    }
                    .buttonStyle(.plain)
                    
                    Button("Complete Setup") {
                        completeSetup()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidSetup)
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 48)
            .padding(.bottom, 48)
        }
        .frame(width: 600, height: 700)
        .background(Theme.Colors.windowBackground)
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
    
    private var biometricName: String {
        switch authManager.biometricType {
        case .touchID:
            return "Touch ID"
        default:
            return "Biometric Authentication"
        }
    }
    
    private var isValidSetup: Bool {
        !password.isEmpty && password == confirmPassword && password.count >= 8
    }
    
    private func completeSetup() {
        guard isValidSetup else { return }
        
        Task {
            do {
                try await authManager.setupInitialAuthentication(
                    password: password,
                    enableBiometric: enableBiometric
                )
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func skipSetup() {
        // Allow skipping setup but mark it as required for next launch
        UserDefaults.standard.set(true, forKey: "hasCompletedInitialSetup")
        authManager.requiresInitialSetup = false
        authManager.isAuthenticated = true
    }
}