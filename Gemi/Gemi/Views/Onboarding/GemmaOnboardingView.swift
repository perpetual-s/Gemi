import SwiftUI

/// Beautiful onboarding experience for Gemma 3n setup
struct GemmaOnboardingView: View {
    @StateObject private var modelManager = GemmaModelManager()
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var currentPage = 0
    @State private var showingSetup = false
    @State private var showingProgressSetup = false
    @State private var hasCompletedOnboarding = false
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var enableBiometric = true
    @State private var showPassword = false
    @State private var isSettingUpPassword = false
    @State private var passwordError = ""
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
            } else if showingSetup {
                setupView
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
            GeometryReader { geometry in
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
                            x: sin(Date().timeIntervalSince1970 * 0.1 + Double(index)) * 200,
                            y: cos(Date().timeIntervalSince1970 * 0.1 + Double(index)) * 200
                        )
                        .animation(
                            .easeInOut(duration: 20 + Double(index * 5))
                            .repeatForever(autoreverses: true),
                            value: Date()
                        )
                }
            }
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
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                
                // Continue button
                Button {
                    handleContinue()
                } label: {
                    HStack {
                        Text(currentPage < totalPages - 1 ? "Continue" : "Get Started")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(width: 200, height: 56)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .white.opacity(0.3), radius: 20, y: 10)
                    )
                }
                .buttonStyle(.plain)
                .disabled(shouldShowPasswordPage && currentPage == 2 && !isPasswordValid)
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
                // Password field
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.5))
                    
                    if showPassword {
                        TextField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18))
                    } else {
                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18))
                    }
                    
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                
                // Confirm password field
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.5))
                    
                    if showPassword {
                        TextField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18))
                    } else {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18))
                    }
                    
                    // Show checkmark when passwords match
                    if !confirmPassword.isEmpty && password == confirmPassword {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                
                // Password requirements
                HStack(spacing: 8) {
                    Image(systemName: password.count >= 6 ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(password.count >= 6 ? .green : .white.opacity(0.5))
                        .font(.system(size: 14))
                    Text("At least 6 characters")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
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
            
            // Skip option
            Button {
                // Skip password setup but allow continuing
                password = ""
                confirmPassword = ""
                withAnimation(.spring(response: 0.4)) {
                    currentPage = 3
                }
            } label: {
                Text("Set up later")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
        .onChange(of: password) { passwordError = "" }
        .onChange(of: confirmPassword) { passwordError = "" }
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
                Task {
                    do {
                        try await authManager.setupInitialAuthentication(
                            password: password,
                            enableBiometric: enableBiometric
                        )
                        withAnimation(.spring(response: 0.4)) {
                            showingSetup = true
                        }
                    } catch {
                        passwordError = error.localizedDescription
                    }
                }
            } else if shouldShowPasswordPage && password.isEmpty {
                // New user skipping password
                UserDefaults.standard.set(true, forKey: "hasCompletedInitialSetup")
                authManager.requiresInitialSetup = false
                authManager.isAuthenticated = true
                withAnimation(.spring(response: 0.4)) {
                    showingSetup = true
                }
            } else {
                // Existing user from Settings
                withAnimation(.spring(response: 0.4)) {
                    showingSetup = true
                }
            }
        }
    }
    
    private var welcomePage3: some View {
        VStack(spacing: 40) {
            // Multimodal icon
            ZStack {
                // Animated circles representing different modalities
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
                        .rotationEffect(.degrees(Date().timeIntervalSince1970 * 20 * (index % 2 == 0 ? 1 : -1)))
                        .animation(
                            .linear(duration: 30).repeatForever(autoreverses: false),
                            value: Date()
                        )
                }
                
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
    
    // MARK: - Setup View
    
    private var setupView: some View {
        VStack(spacing: 40) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.purple.opacity(0.5), radius: 20)
                
                Text("Let's Set Up Gemma 3n")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("One-time download to enable AI features")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.top, 80)
            
            // Status content
            Group {
                switch modelManager.status {
                case .notInstalled, .checking:
                    setupInstructions
                case .downloading(let progress):
                    downloadProgress(progress: progress)
                case .ready:
                    setupComplete
                case .error(let message):
                    setupError(message: message)
                }
            }
            .frame(maxWidth: 600)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Setup States
    
    private var setupInstructions: some View {
        VStack(spacing: 32) {
            // Requirements
            VStack(alignment: .leading, spacing: 20) {
                Label("8GB download (one-time)", systemImage: "arrow.down.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
                
                Label("20GB free space recommended", systemImage: "internaldrive")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
                
                Label("Stable internet connection", systemImage: "wifi")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
                
                Label("Terminal will open for setup", systemImage: "terminal")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // Action buttons
            VStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        showingProgressSetup = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                        Text("Set Up Gemma 3n")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(width: 280, height: 56)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .white.opacity(0.3), radius: 20, y: 10)
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    // Skip for now - they can download later
                    safeComplete()
                } label: {
                    Text("Set up later")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func downloadProgress(progress: Double) -> some View {
        VStack(spacing: 32) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 12)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                
                VStack(spacing: 8) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(modelManager.downloadTimeEstimate)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Tips
            VStack(alignment: .leading, spacing: 16) {
                Text("While downloading...")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("• Feel free to explore Gemi")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("• The download continues in background")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("• This is a one-time process")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    private var setupComplete: some View {
        VStack(spacing: 32) {
            // Success animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .blur(radius: 40)
                
                Image(systemName: "checkmark.circle.fill")
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
                Text("All Set!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Gemma 3n is ready to assist you")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Button {
                safeComplete()
            } label: {
                Text("Start Using Gemi")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 280, height: 56)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .white.opacity(0.3), radius: 20, y: 10)
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func setupError(message: String) -> some View {
        VStack(spacing: 32) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            VStack(spacing: 16) {
                Text("Setup Issue")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Button {
                        modelManager.retry()
                    } label: {
                        Text("Try Again")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        ModelSetupHelper.openManualSetup()
                    } label: {
                        HStack {
                            Image(systemName: "terminal")
                                .font(.system(size: 14))
                            Text("Open Terminal")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    // Skip for now
                    safeComplete()
                } label: {
                    Text("Set up later")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
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