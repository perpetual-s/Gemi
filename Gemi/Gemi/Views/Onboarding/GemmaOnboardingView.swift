import SwiftUI

/// Beautiful onboarding experience for Gemma 3n setup
struct GemmaOnboardingView: View {
    @StateObject private var modelManager = GemmaModelManager()
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var currentPage = 0
    @State private var showingProgressSetup = false
    @State private var hasCompletedOnboarding = false
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var enableBiometric = true
    @State private var showPassword = false
    @State private var isSettingUpPassword = false
    @State private var passwordError = ""
    @State private var showPasswordError = false
    @Environment(\.dismiss) var dismiss
    
    let onComplete: () -> Void
    
    // Determine if we should show password setup (only for new users)
    private var shouldShowPasswordPage: Bool {
        authManager.requiresInitialSetup
    }
    
    // Adjust page count based on whether password setup is needed
    private var totalPages: Int {
        shouldShowPasswordPage ? 4 : 3
    }
    
    private func safeComplete() {
        guard !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
        
        // Ensure we're on the main thread and delay slightly to avoid state update conflicts
        DispatchQueue.main.async {
            onComplete()
        }
    }
    
    var body: some View {
        ZStack {
            // Beautiful gradient background
            backgroundGradient
            
            // Content based on state
            if showingProgressSetup {
                GemmaSetupProgressView(
                    onComplete: safeComplete,
                    onSkip: {
                        showingProgressSetup = false
                        safeComplete()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                welcomeFlow
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
        .onAppear {
            // Don't check status immediately - server isn't running yet
            modelManager.status = .notInstalled
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)
            
            // Animated mesh gradient overlay
            AnimatedGradientMesh()
                .opacity(0.5)
        }
    }
    
    // MARK: - Welcome Flow
    
    private var welcomeFlow: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Page content with custom transitions
            ZStack {
                if currentPage == 0 {
                    welcomePage1
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else if currentPage == 1 {
                    welcomePage2
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else if currentPage == 2 {
                    if shouldShowPasswordPage {
                        passwordSetupPage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        welcomePage3
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                } else if currentPage == 3 {
                    welcomePage3
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.5), value: currentPage)
            
            Spacer()
            
            // Page indicators and navigation
            VStack(spacing: 24) {
                // Custom page indicators
                StepProgressIndicator(totalSteps: totalPages, currentStep: currentPage)
                
                // Continue button
                OnboardingButton(
                    currentPage < totalPages - 1 ? "Continue" : "Get Started",
                    icon: isSettingUpPassword ? nil : "arrow.right",
                    isLoading: isSettingUpPassword,
                    action: handleContinue
                )
                .disabled((shouldShowPasswordPage && currentPage == 2 && !isPasswordValid) || isSettingUpPassword)
            }
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Welcome Pages
    
    private var welcomePage1: some View {
        VStack(spacing: 32) {
            // Animated logo
            SparkleAnimationView()
            
            VStack(spacing: 16) {
                Text("Welcome to Gemi")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("Your private AI journal companion")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    
    private var welcomePage2: some View {
        VStack(spacing: 40) {
            // Privacy icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.green.opacity(0.5), radius: 20)
            }
            
            VStack(spacing: 16) {
                Text("100% Private")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Everything stays on your Mac.\nNo cloud. No servers. Just you.")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 40)
    }
    
    private var passwordSetupPage: some View {
        VStack(spacing: 40) {
            // Security icon with animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 100))
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
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Create a password to protect your thoughts")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
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
                            Text("Enable Touch ID")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: 400)
            
        }
        .padding(.horizontal, 40)
        .onChange(of: password) { 
            passwordError = "" 
            showPasswordError = false
        }
        .onChange(of: confirmPassword) { 
            passwordError = "" 
            showPasswordError = false
        }
        .alert("Password Setup Error", isPresented: $showPasswordError) {
            Button("OK") { }
        } message: {
            Text(passwordError)
        }
    }
    
    private var isPasswordValid: Bool {
        password.count >= 6 && password == confirmPassword
    }
    
    private func handleContinue() {
        if currentPage < totalPages - 1 {
            withAnimation(.spring(response: 0.4)) {
                currentPage += 1
            }
        } else {
            // Last page - handle setup
            if shouldShowPasswordPage && !password.isEmpty && isPasswordValid {
                // New user with password
                isSettingUpPassword = true
                Task {
                    do {
                        try await authManager.setupInitialAuthentication(
                            password: password,
                            enableBiometric: enableBiometric
                        )
                        withAnimation(.spring(response: 0.4)) {
                            showingProgressSetup = true
                        }
                    } catch {
                        await MainActor.run {
                            isSettingUpPassword = false
                            passwordError = error.localizedDescription
                            showPasswordError = true
                        }
                    }
                }
            } else if shouldShowPasswordPage && password.isEmpty {
                // Password is required - show error
                passwordError = "Password is required to secure your journal"
                showPasswordError = true
                // Go back to password page
                withAnimation(.spring(response: 0.4)) {
                    currentPage = totalPages - 2 // Go back to password page
                }
            } else {
                // Existing user from Settings
                withAnimation(.spring(response: 0.4)) {
                    showingProgressSetup = true
                }
            }
        }
    }
    
    private var welcomePage3: some View {
        VStack(spacing: 40) {
            // Multimodal icon
            ZStack {
                // Animated circles representing different modalities
                AnimatedModalityRings()
                
                // Center icon
                Image(systemName: "cpu.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 16) {
                Text("Powered by Gemma 3n")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Understands text, images, and more.\nGoogle DeepMind's latest AI, just for you.")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Helpers
    
    private func colorForModality(_ index: Int) -> Color {
        switch index {
        case 0: return .blue
        case 1: return .purple
        case 2: return .pink
        case 3: return .orange
        default: return .white
        }
    }
}

// MARK: - Optimized Animation Components

/// Performant animated gradient mesh without Date-based animations
struct AnimatedGradientMesh: View {
    @State private var phase: Double = 0
    @State private var animateGradient = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(0.3 - Double(index) * 0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 100,
                                endRadius: 300
                            )
                        )
                        .frame(width: 600, height: 600)
                        .blur(radius: 80)
                        .offset(
                            x: animateGradient ? 200 : -200,
                            y: animateGradient ? 100 : -100
                        )
                        .animation(
                            .easeInOut(duration: 20 + Double(index * 5))
                            .repeatForever(autoreverses: true),
                            value: animateGradient
                        )
                        .rotationEffect(.degrees(Double(index) * 120))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            animateGradient = true
        }
    }
}

/// Optimized animated rings for modalities
struct AnimatedModalityRings: View {
    @State private var rotationAngles: [Double] = [0, 0, 0, 0]
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<4) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                colorForModality(index),
                                colorForModality(index).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(
                        width: 120 + CGFloat(index * 30),
                        height: 120 + CGFloat(index * 30)
                    )
                    .rotationEffect(.degrees(rotationAngles[index]))
                    .animation(
                        .linear(duration: 30)
                        .repeatForever(autoreverses: false),
                        value: rotationAngles[index]
                    )
            }
        }
        .onAppear {
            for index in 0..<4 {
                rotationAngles[index] = 360 * (index % 2 == 0 ? 1 : -1)
            }
        }
    }
    
    private func colorForModality(_ index: Int) -> Color {
        switch index {
        case 0: return .blue
        case 1: return .purple
        case 2: return .pink
        case 3: return .orange
        default: return .white
        }
    }
}