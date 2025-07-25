import SwiftUI

/// Beautiful onboarding experience for Gemma 3n setup
struct GemmaOnboardingView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var ollamaService = OllamaChatService.shared
    @State private var currentPage = 0
    @State private var hasCompletedOnboarding = false
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var enableBiometric = true
    @State private var showPassword = false
    @State private var isSettingUpPassword = false
    @State private var passwordError = ""
    @State private var showPasswordError = false
    @State private var contentOpacity: Double = 1.0
    
    // Ollama setup states
    @State private var isCheckingOllama = false
    @State private var ollamaStatus: OllamaStatus = .notChecked
    @State private var showCopyConfirmation = false
    @State private var copiedCommand = ""
    
    @Environment(\.dismiss) var dismiss
    
    enum OllamaStatus: Equatable {
        case notChecked
        case notInstalled
        case installedNotRunning
        case runningNoModel
        case ready
        case error(String)
    }
    
    let onComplete: () -> Void
    
    // Determine if we should show password setup (only for new users)
    private var shouldShowPasswordPage: Bool {
        authManager.requiresInitialSetup
    }
    
    // Adjust page count based on whether password setup is needed
    // Welcome (1) + Privacy (1) + [Password (1)] + Gemma3n (1) + Ollama Setup (3) = 6 or 7 total
    private var totalPages: Int {
        shouldShowPasswordPage ? 7 : 6
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
            
            // Main welcome flow content
            welcomeFlow
                .opacity(contentOpacity)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
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
                    if shouldShowPasswordPage {
                        welcomePage3
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        // Ollama setup step 1 for users without password
                        installOllamaStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                } else if currentPage == 4 {
                    if shouldShowPasswordPage {
                        // Ollama setup step 1 for users with password
                        installOllamaStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        // Ollama setup step 2 for users without password
                        downloadModelStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                } else if currentPage == 5 {
                    if shouldShowPasswordPage {
                        // Ollama setup step 2 for users with password
                        downloadModelStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        // Ollama setup step 3 (verify) for users without password
                        verificationStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                } else if currentPage == 6 {
                    // Ollama setup step 3 (verify) for users with password
                    verificationStep
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
                if isOnVerificationStep && ollamaStatus != .ready {
                    // Check status button when on verification step
                    OnboardingButton(
                        isCheckingOllama ? "Checking..." : "Check Status",
                        icon: isCheckingOllama ? nil : "arrow.clockwise",
                        style: .secondary,
                        isLoading: isCheckingOllama,
                        action: {
                            Task {
                                await checkOllamaStatus()
                            }
                        }
                    )
                    .disabled(isCheckingOllama)
                } else {
                    OnboardingButton(
                        currentPage < totalPages - 1 ? "Continue" : "Get Started",
                        icon: isSettingUpPassword ? nil : "arrow.right",
                        isLoading: isSettingUpPassword,
                        action: handleContinue
                    )
                    .disabled((shouldShowPasswordPage && currentPage == 2 && !isPasswordValid) || 
                             isSettingUpPassword ||
                             (isOnVerificationStep && ollamaStatus != .ready))
                }
            }
            .padding(.bottom, 60)
        }
        .overlay(
            // Copy confirmation toast overlay
            Group {
                if showCopyConfirmation {
                    VStack {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Command copied!")
                                .font(.footnote)
                                .foregroundColor(.white)
                            Text(copiedCommand)
                                .font(.footnote.monospaced())
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.8))
                                .background(.ultraThinMaterial)
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 20)
                    .allowsHitTesting(false)
                }
            }
        )
        .task {
            // Check Ollama status when reaching the verification page
            if isOnVerificationStep {
                await checkOllamaStatus()
            }
        }
        .onChange(of: currentPage) { oldValue, newValue in
            // Check Ollama status when reaching the verification page
            if isOnVerificationStep {
                Task {
                    await checkOllamaStatus()
                }
            }
        }
    }
    
    // Helper to check if we're on the verification step
    private var isOnVerificationStep: Bool {
        if shouldShowPasswordPage {
            return currentPage == 6
        } else {
            return currentPage == 5
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
        .onChange(of: password) { _, _ in
            passwordError = "" 
            showPasswordError = false
        }
        .onChange(of: confirmPassword) { _, _ in
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
            if shouldShowPasswordPage && currentPage == 2 {
                // Handle password setup
                if !password.isEmpty && isPasswordValid {
                    isSettingUpPassword = true
                    Task {
                        do {
                            try await authManager.setupInitialAuthentication(
                                password: password,
                                enableBiometric: enableBiometric
                            )
                            await MainActor.run {
                                isSettingUpPassword = false
                                // Continue to next page
                                withAnimation(.spring(response: 0.4)) {
                                    currentPage += 1
                                }
                            }
                        } catch {
                            await MainActor.run {
                                isSettingUpPassword = false
                                passwordError = error.localizedDescription
                                showPasswordError = true
                            }
                        }
                    }
                } else {
                    // Password is required - show error
                    passwordError = "Password is required to secure your journal"
                    showPasswordError = true
                }
            } else {
                // Complete onboarding
                safeComplete()
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
    
    // MARK: - Ollama Setup Pages
    
    @ViewBuilder
    var installOllamaStep: some View {
        VStack(spacing: 24) {
            // Icon and main title
            VStack(spacing: 16) {
                // Animated icon container
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)
                    
                    // Terminal icon with gradient
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .blue.opacity(0.5), radius: 10)
                }
                
                VStack(spacing: 12) {
                    Text("Set Up Ollama")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Gemi uses Ollama to run AI locally on your Mac")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 16) {
                Text("Step 1: Install Ollama")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Choose your installation method:")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            VStack(spacing: 20) {
                // Option 1: Homebrew
                VStack(spacing: 12) {
                    Text("Option 1: Install via Homebrew")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    CommandBox(
                        command: "brew install ollama",
                        description: "For developers comfortable with Terminal"
                    ) {
                        copyToClipboard("brew install ollama")
                    }
                }
                
                HStack(spacing: 16) {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                    
                    Text("OR")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                }
                
                // Option 2: Direct download
                VStack(spacing: 12) {
                    Text("Option 2: Download Installer")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    OnboardingButton(
                        "Download Ollama.dmg",
                        icon: "arrow.down.circle",
                        style: .secondary,
                        action: {
                            NSWorkspace.shared.open(URL(string: "https://ollama.com/download")!)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 30)
    }
    
    @ViewBuilder
    var downloadModelStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("Step 2: Download Gemma 3n")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Run these commands in Terminal:")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            VStack(spacing: 16) {
                CommandBox(
                    command: "ollama serve",
                    description: "Start the Ollama server"
                ) {
                    copyToClipboard("ollama serve")
                }
                
                Text("Then in a new Terminal tab:")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.vertical, 4)
                
                CommandBox(
                    command: "ollama run gemma3n:latest",
                    description: "Download and run Gemma 3n model (7.5GB)"
                ) {
                    copyToClipboard("ollama run gemma3n:latest")
                }
            }
            
            // Progress indicator using OnboardingFeatureCard
            OnboardingFeatureCard(
                items: [
                    (icon: "arrow.down.circle.fill", text: "This downloads a 7.5GB model"),
                    (icon: "clock.fill", text: "Download time depends on your internet speed"),
                    (icon: "checkmark.circle.fill", text: "You'll see progress in Terminal")
                ]
            )
        }
        .padding(.horizontal, 30)
    }
    
    @ViewBuilder
    var verificationStep: some View {
        VStack(spacing: 32) {
            Text("Step 3: Verify Setup")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Status display
            Group {
                switch ollamaStatus {
                case .notChecked, .notInstalled:
                    StatusCard(
                        icon: "xmark.circle",
                        iconColor: .red,
                        title: "Ollama Not Found",
                        description: "Please complete steps 1 and 2",
                        status: .error
                    )
                    
                case .installedNotRunning:
                    StatusCard(
                        icon: "pause.circle",
                        iconColor: .orange,
                        title: "Ollama Not Running",
                        description: "Run 'ollama serve' in Terminal",
                        status: .warning
                    )
                    
                case .runningNoModel:
                    StatusCard(
                        icon: "arrow.down.circle",
                        iconColor: .blue,
                        title: "Model Not Downloaded",
                        description: "Run 'ollama pull gemma3n:latest'",
                        status: .info
                    )
                    
                case .ready:
                    StatusCard(
                        icon: "checkmark.circle",
                        iconColor: .green,
                        title: "Ready to Go!",
                        description: "Ollama and Gemma 3n are set up correctly",
                        status: .success
                    )
                    
                case .error(let message):
                    StatusCard(
                        icon: "exclamationmark.triangle",
                        iconColor: .red,
                        title: "Setup Error",
                        description: message,
                        status: .error
                    )
                }
            }
            .transition(.opacity.combined(with: .scale))
            
            if ollamaStatus != .ready {
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Need help with setup?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "https://github.com/ollama/ollama#macos")!)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 14))
                            Text("Open Setup Guide")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Open Ollama documentation in your browser")
                }
            }
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - Ollama Helper Methods
    
    private func checkOllamaStatus() async {
        isCheckingOllama = true
        
        // Check if Ollama is installed
        let isInstalled = await OllamaInstaller.shared.checkInstallation()
        
        if !isInstalled {
            withAnimation {
                ollamaStatus = .notInstalled
                isCheckingOllama = false
            }
            return
        }
        
        // Check if Ollama is running
        let health = await ollamaService.health()
        
        if !health.healthy {
            withAnimation {
                ollamaStatus = .installedNotRunning
                isCheckingOllama = false
            }
            return
        }
        
        // Check if model is available
        if !health.modelLoaded {
            withAnimation {
                ollamaStatus = .runningNoModel
                isCheckingOllama = false
            }
            return
        }
        
        // All good!
        withAnimation {
            ollamaStatus = .ready
            isCheckingOllama = false
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        // Show confirmation
        copiedCommand = text
        withAnimation(.spring()) {
            showCopyConfirmation = true
        }
        
        // Hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring()) {
                showCopyConfirmation = false
            }
        }
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

// MARK: - Supporting Views

struct CommandBox: View {
    let command: String
    let description: String
    let onCopy: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(command)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.8))
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(.spring(response: 0.2), value: isPressed)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Copy command")
            .onHover { hovering in
                isHovered = hovering
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
    }
}

struct StatusCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let status: Status
    
    enum Status {
        case success, warning, error, info
        
        var backgroundColor: Color {
            switch self {
            case .success: return .green.opacity(0.15)
            case .warning: return .orange.opacity(0.15)
            case .error: return .red.opacity(0.15)
            case .info: return .blue.opacity(0.15)
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            status.backgroundColor,
                            status.backgroundColor.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            iconColor.opacity(0.4),
                            iconColor.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: iconColor.opacity(0.2), radius: 8, x: 0, y: 4)
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