import SwiftUI

/// Guides users through manual Ollama installation
struct OllamaSetupView: View {
    @StateObject private var ollamaService = OllamaChatService.shared
    @State private var currentStep = 0
    @State private var isCheckingOllama = false
    @State private var ollamaStatus: OllamaStatus = .notChecked
    @State private var showCopyConfirmation = false
    @State private var copiedCommand = ""
    @State private var animateGradient = false
    
    let onCompletion: () -> Void
    
    enum OllamaStatus: Equatable {
        case notChecked
        case notInstalled
        case installedNotRunning
        case runningNoModel
        case ready
        case error(String)
    }
    
    var body: some View {
        ZStack {
            // Beautiful gradient background matching other onboarding views
            backgroundGradient
            
            VStack(spacing: 0) {
                // Header with enhanced styling
                VStack(spacing: 20) {
                    // Animated icon container
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.blue.opacity(0.3),
                                        Color.purple.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)
                            .blur(radius: 10)
                            .scaleEffect(animateGradient ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateGradient)
                        
                        // Terminal icon with gradient
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    
                    VStack(spacing: 12) {
                        Text("Set Up Ollama")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Gemi uses Ollama to run AI locally on your Mac")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal, 60)
            
                // Enhanced progress indicator
                HStack(spacing: 20) {
                    ForEach(0..<3) { index in
                        ZStack {
                            // Background circle
                            Circle()
                                .fill(
                                    currentStep >= index ?
                                    AnyShapeStyle(LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )) :
                                    AnyShapeStyle(Color.white.opacity(0.2))
                                )
                                .frame(width: 10, height: 10)
                                .shadow(color: currentStep >= index ? .blue.opacity(0.5) : .clear, 
                                       radius: 4, x: 0, y: 2)
                            
                            // Animated ring for current step
                            if currentStep == index {
                                Circle()
                                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
                                    .frame(width: 16, height: 16)
                                    .scaleEffect(animateGradient ? 1.2 : 1.0)
                                    .opacity(animateGradient ? 0.0 : 1.0)
                                    .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: animateGradient)
                            }
                        }
                        .animation(.spring(), value: currentStep)
                    }
                }
                .padding(.vertical, 30)
            
            // Content
            Group {
                switch currentStep {
                case 0:
                    installOllamaStep
                case 1:
                    downloadModelStep
                case 2:
                    verificationStep
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 60)
            
                // Premium footer buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation(.spring()) {
                                currentStep -= 1
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                    
                    if currentStep < 2 {
                        OnboardingButton(
                            "Next",
                            icon: "arrow.right",
                            style: .primary
                        ) {
                            withAnimation(.spring()) {
                                currentStep += 1
                            }
                        }
                    } else if ollamaStatus == .ready {
                        OnboardingButton(
                            "Get Started",
                            icon: "sparkles",
                            style: .primary
                        ) {
                            onCompletion()
                        }
                        .keyboardShortcut(.return)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 40)
            
                // Copy confirmation toast
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
        }
        .frame(width: 700, height: 600)
        .task {
            await checkOllamaStatus()
        }
        .onAppear {
            animateGradient = true
        }
    }
    
    // MARK: - Background Gradient
    
    private var backgroundGradient: some View {
        ZStack {
            // Base gradient matching other onboarding views
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)
            
            // Animated accent gradient
            RadialGradient(
                colors: [
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.2),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .scaleEffect(animateGradient ? 1.5 : 1.0)
            .opacity(animateGradient ? 0.6 : 0.4)
            .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animateGradient)
            .ignoresSafeArea(.all)
        }
    }
    
    // MARK: - Step Views
    
    @ViewBuilder
    var installOllamaStep: some View {
        VStack(spacing: 24) {
            Text("Step 1: Install Ollama")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Open Terminal and run this command:")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
            
            CommandBox(
                command: "brew install ollama",
                description: "Installs Ollama using Homebrew"
            ) {
                copyToClipboard("brew install ollama")
            }
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Don't have Homebrew? Visit ")
                    .foregroundColor(.white.opacity(0.7))
                    + Text("brew.sh")
                    .foregroundColor(.blue)
                    .underline()
            }
            .font(.footnote)
            .onTapGesture {
                NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical)
            
            Text("Alternative: Download from Ollama.com")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Button(action: {
                NSWorkspace.shared.open(URL(string: "https://ollama.com/download")!)
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18))
                    Text("Download Ollama")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(1.0)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    var downloadModelStep: some View {
        VStack(spacing: 24) {
            Text("Step 2: Download Gemma 3n")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Run these commands in Terminal:")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
            
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
            
            // Enhanced progress indicator
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    Text("This downloads a 7.5GB model")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 20))
                    Text("Download time depends on your internet speed")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                    Text("You'll see progress in Terminal")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    var verificationStep: some View {
        VStack(spacing: 24) {
            Text("Step 3: Verify Setup")
                .font(.system(size: 28, weight: .bold, design: .rounded))
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
            
            // Premium check button
            Button(action: {
                Task {
                    await checkOllamaStatus()
                }
            }) {
                HStack(spacing: 10) {
                    if isCheckingOllama {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                    }
                    Text(isCheckingOllama ? "Checking..." : "Check Again")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isCheckingOllama)
            .opacity(isCheckingOllama ? 0.7 : 1.0)
            
            if ollamaStatus != .ready {
                VStack(spacing: 12) {
                    Text("Need help?")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Button("Open Setup Guide") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/ollama/ollama#macos")!)
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .underline()
                }
                .padding(.top)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
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
            case .success: return .green.opacity(0.1)
            case .warning: return .orange.opacity(0.1)
            case .error: return .red.opacity(0.1)
            case .info: return .blue.opacity(0.1)
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
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(status.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(iconColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

struct OllamaSetupView_Previews: PreviewProvider {
    static var previews: some View {
        OllamaSetupView {
            print("Setup completed")
        }
    }
}