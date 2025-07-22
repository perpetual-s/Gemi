import SwiftUI

/// Guides users through manual Ollama installation
struct OllamaSetupView: View {
    @StateObject private var ollamaService = OllamaChatService.shared
    @State private var currentStep = 0
    @State private var isCheckingOllama = false
    @State private var ollamaStatus: OllamaStatus = .notChecked
    @State private var showCopyConfirmation = false
    @State private var copiedCommand = ""
    
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
            // Header
            VStack(spacing: 16) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Set Up Ollama")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Gemi uses Ollama to run AI locally on your Mac")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.horizontal, 60)
            
            // Progress indicator
            HStack(spacing: 20) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(currentStep >= index ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
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
            
            // Footer buttons
            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation(.spring()) {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if currentStep < 2 {
                    Button("Next") {
                        withAnimation(.spring()) {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if ollamaStatus == .ready {
                    Button("Get Started") {
                        onCompletion()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
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
                        Text(copiedCommand)
                            .font(.footnote.monospaced())
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 20)
                .allowsHitTesting(false)
            }
        }
        .frame(width: 700, height: 600)
        .task {
            await checkOllamaStatus()
        }
    }
    
    // MARK: - Step Views
    
    @ViewBuilder
    var installOllamaStep: some View {
        VStack(spacing: 24) {
            Text("Step 1: Install Ollama")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Open Terminal and run this command:")
                .font(.body)
                .foregroundColor(.secondary)
            
            CommandBox(
                command: "brew install ollama",
                description: "Installs Ollama using Homebrew"
            ) {
                copyToClipboard("brew install ollama")
            }
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Don't have Homebrew? Visit ")
                    .foregroundColor(.secondary)
                    + Text("brew.sh")
                    .foregroundColor(.blue)
                    .underline()
            }
            .font(.footnote)
            .onTapGesture {
                NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
            }
            
            Divider()
                .padding(.vertical)
            
            Text("Alternative: Download from Ollama.com")
                .font(.headline)
            
            Button(action: {
                NSWorkspace.shared.open(URL(string: "https://ollama.com/download")!)
            }) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text("Download Ollama")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    var downloadModelStep: some View {
        VStack(spacing: 24) {
            Text("Step 2: Download Gemma 3n")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Run these commands in Terminal:")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                CommandBox(
                    command: "ollama serve",
                    description: "Start the Ollama server"
                ) {
                    copyToClipboard("ollama serve")
                }
                
                Text("Then in a new Terminal tab:")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                CommandBox(
                    command: "ollama run gemma3n:latest",
                    description: "Download and run Gemma 3n model (7.5GB)"
                ) {
                    copyToClipboard("ollama run gemma3n:latest")
                }
            }
            
            // Progress indicator
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.blue)
                    Text("This downloads a 7.5GB model")
                        .font(.footnote)
                }
                
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    Text("Download time depends on your internet speed")
                        .font(.footnote)
                }
                
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("You'll see progress in Terminal")
                        .font(.footnote)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
            )
            
            Spacer()
        }
    }
    
    @ViewBuilder
    var verificationStep: some View {
        VStack(spacing: 24) {
            Text("Step 3: Verify Setup")
                .font(.title2)
                .fontWeight(.semibold)
            
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
            
            // Check button
            Button(action: {
                Task {
                    await checkOllamaStatus()
                }
            }) {
                HStack {
                    if isCheckingOllama {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(isCheckingOllama ? "Checking..." : "Check Again")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .disabled(isCheckingOllama)
            
            if ollamaStatus != .ready {
                VStack(spacing: 12) {
                    Text("Need help?")
                        .font(.headline)
                    
                    Button("Open Setup Guide") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/ollama/ollama#macos")!)
                    }
                    .buttonStyle(.link)
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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(command)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("Copy command")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
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