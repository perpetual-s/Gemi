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
        VStack(spacing: 0) {
            Spacer()
            
            // Content based on step
            ZStack {
                switch currentStep {
                case 0:
                    installOllamaStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case 1:
                    downloadModelStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case 2:
                    verificationStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                default:
                    EmptyView()
                }
            }
            .animation(.spring(response: 0.5), value: currentStep)
            
            Spacer()
            
            // Fixed navigation area matching GemmaOnboardingView
            VStack(spacing: 24) {
                // Custom page indicators
                StepProgressIndicator(totalSteps: 3, currentStep: currentStep)
                
                // Navigation buttons
                if currentStep < 2 {
                    OnboardingButton(
                        "Continue",
                        icon: "arrow.right",
                        action: {
                            withAnimation(.spring()) {
                                currentStep += 1
                            }
                        }
                    )
                } else if ollamaStatus == .ready {
                    OnboardingButton(
                        "Get Started",
                        icon: "sparkles",
                        action: onCompletion
                    )
                    .keyboardShortcut(.return)
                } else {
                    // Check status button when not ready
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
                }
                
                // Back button when not on first step
                if currentStep > 0 {
                    Button(action: {
                        withAnimation(.spring()) {
                            currentStep -= 1
                        }
                    }) {
                        Text("Back")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.bottom, 60)
            
        }
        .frame(width: 700, height: 600)
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
            await checkOllamaStatus()
        }
    }
    
    // MARK: - Step Views
    
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
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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

// MARK: - Preview

struct OllamaSetupView_Previews: PreviewProvider {
    static var previews: some View {
        OllamaSetupView {
            print("Setup completed")
        }
    }
}