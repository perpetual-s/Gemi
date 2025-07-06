import SwiftUI
import LocalAuthentication

struct AuthenticationView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var password = ""
    @State private var showingError = false
    @FocusState private var passwordFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // App icon and title
            VStack(spacing: 16) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Theme.Colors.primaryAccent)
                
                Text("Welcome to Gemi")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                
                Text("Your private journal")
                    .font(.title3)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.vertical, 48)
            
            // Authentication section
            VStack(spacing: 20) {
                if authManager.isBiometricAvailable && authManager.isBiometricEnabled {
                    Button(action: authenticateWithBiometric) {
                        Label(biometricButtonTitle, systemImage: biometricIcon)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Text("or")
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                // Password field
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                    .focused($passwordFieldFocused)
                    .onSubmit {
                        authenticateWithPassword()
                    }
                
                Button("Unlock", action: authenticateWithPassword)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(password.isEmpty || authManager.isAuthenticating)
                    .keyboardShortcut(.return)
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 48)
        }
        .frame(width: 480, height: 600)
        .background(Theme.Colors.windowBackground)
        .onAppear {
            passwordFieldFocused = true
            
            // Auto-trigger biometric if available
            if authManager.isBiometricAvailable && authManager.isBiometricEnabled {
                authenticateWithBiometric()
            }
        }
        .alert("Authentication Error", isPresented: $showingError) {
            Button("OK") {
                passwordFieldFocused = true
            }
        } message: {
            Text(authManager.authenticationError?.localizedDescription ?? "Unknown error")
        }
        .onChange(of: authManager.authenticationError) { _, newError in
            showingError = newError != nil
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
            return "lock.shield"
        }
    }
    
    private func authenticateWithBiometric() {
        Task {
            do {
                try await authManager.authenticate()
            } catch {
                authManager.authenticationError = error as? AuthenticationError
            }
        }
    }
    
    private func authenticateWithPassword() {
        guard !password.isEmpty else { return }
        
        Task {
            do {
                try await authManager.authenticateWithPassword(password)
            } catch {
                authManager.authenticationError = error as? AuthenticationError
                password = ""
                passwordFieldFocused = true
            }
        }
    }
}