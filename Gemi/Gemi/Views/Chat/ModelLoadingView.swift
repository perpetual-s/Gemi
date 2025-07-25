import SwiftUI

/// Elegant model loading view that replaces the overlapping notifications
struct ModelLoadingView: View {
    @StateObject private var viewModel = ModelLoadingViewModel()
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)
            
            // Animated Ollama icon
            ZStack {
                // Pulsing background circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Theme.Colors.primaryAccent.opacity(0.15),
                                Theme.Colors.primaryAccent.opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0.3 : 0.6)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
                
                // Inner circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.Colors.primaryAccent.opacity(0.8),
                                Theme.Colors.primaryAccent
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        // Ollama-inspired icon
                        Text("🦙")
                            .font(.system(size: 48))
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
                    )
            }
            
            // Status content
            VStack(spacing: 16) {
                // Main status text
                Group {
                    switch viewModel.status {
                    case .checking:
                        Text("Preparing your AI companion")
                            .font(Theme.Typography.largeTitle)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.primary, Color.primary.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                    case .starting:
                        Text("Starting Ollama")
                            .font(Theme.Typography.largeTitle)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.primary, Color.primary.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                    case .loadingModel:
                        VStack(spacing: 8) {
                            Text("Loading Gemma 3n")
                                .font(Theme.Typography.largeTitle)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.primary, Color.primary.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            if viewModel.loadingProgress > 0 {
                                ProgressView(value: viewModel.loadingProgress)
                                    .progressViewStyle(.linear)
                                    .tint(Theme.Colors.primaryAccent)
                                    .frame(width: 200)
                                
                                Text("\(Int(viewModel.loadingProgress * 100))%")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.secondaryText)
                                    .monospacedDigit()
                            }
                        }
                        
                    case .notInstalled:
                        Text("Ollama not installed")
                            .font(Theme.Typography.largeTitle)
                            .foregroundColor(.orange)
                        
                    case .error:
                        Text("Connection issue")
                            .font(Theme.Typography.largeTitle)
                            .foregroundColor(.red)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
                // Subtitle
                Text(viewModel.subtitle)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                
                // Action section
                Group {
                    switch viewModel.status {
                    case .notInstalled:
                        VStack(spacing: 12) {
                            Button {
                                Task {
                                    await viewModel.installOllama()
                                }
                            } label: {
                                Label("Install Ollama", systemImage: "arrow.down.circle.fill")
                                    .font(Theme.Typography.body)
                                    .fontWeight(.medium)
                                    .frame(minWidth: 180)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            
                            Link("Manual Installation Guide", 
                                 destination: URL(string: "https://ollama.com/download")!)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.primaryAccent)
                        }
                        
                    case .error:
                        VStack(spacing: 12) {
                            Button {
                                Task {
                                    await viewModel.retry()
                                }
                            } label: {
                                Label("Try Again", systemImage: "arrow.clockwise")
                                    .font(Theme.Typography.body)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            
                            // Manual start option
                            Button {
                                viewModel.openTerminalForManualStart()
                            } label: {
                                Text("Start Manually in Terminal")
                                    .font(Theme.Typography.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(Theme.Colors.primaryAccent)
                        }
                        
                    case .checking, .starting, .loadingModel:
                        // Show elegant loading indicator
                        ProgressView()
                            .controlSize(.small)
                            .tint(Theme.Colors.primaryAccent)
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: 400)
            
            // Privacy badge
            HStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("Everything stays on your device")
                    .font(Theme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.08))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.top, 24)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            pulseAnimation = true
            Task {
                await viewModel.startSetup()
            }
        }
    }
}

/// View model for handling model loading state
@MainActor
final class ModelLoadingViewModel: ObservableObject {
    @Published var status: LoadingStatus = .checking
    @Published var subtitle = "One moment while we prepare your private AI"
    @Published var loadingProgress: Double = 0.0
    
    private let ollamaService = OllamaChatService.shared
    private let installer = OllamaInstaller.shared
    
    enum LoadingStatus: Equatable {
        case checking
        case starting
        case loadingModel
        case notInstalled
        case error(String)
        
        static func == (lhs: LoadingStatus, rhs: LoadingStatus) -> Bool {
            switch (lhs, rhs) {
            case (.checking, .checking),
                 (.starting, .starting),
                 (.loadingModel, .loadingModel),
                 (.notInstalled, .notInstalled):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }
    
    func startSetup() async {
        status = .checking
        subtitle = "Checking Ollama installation..."
        
        // Step 1: Check if Ollama is installed
        let isInstalled = await installer.checkInstallation()
        
        if !isInstalled {
            status = .notInstalled
            subtitle = "Ollama is required to run Gemma 3n locally"
            return
        }
        
        // Step 2: Check if Ollama is running
        let health = await ollamaService.health()
        
        if !health.healthy {
            status = .starting
            subtitle = "Starting Ollama server..."
            
            // Try to start Ollama
            do {
                try await installer.startOllamaServer()
                // Wait a moment for server to stabilize
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                status = .error("Failed to start Ollama")
                subtitle = "You can start it manually with 'ollama serve'"
                return
            }
        }
        
        // Step 3: Check if model is loaded
        let modelHealth = await ollamaService.health()
        
        if !modelHealth.modelLoaded {
            status = .loadingModel
            subtitle = "First time setup: downloading Gemma 3n (7.5GB)"
            
            // Start model loading with progress tracking
            await loadModelWithProgress()
        }
    }
    
    private func loadModelWithProgress() async {
        do {
            // Create a task to monitor progress
            let progressTask = Task {
                while !Task.isCancelled {
                    // Simulate progress (in real implementation, get from Ollama)
                    if loadingProgress < 0.95 {
                        loadingProgress += 0.01
                    }
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
            }
            
            // Load the model
            try await ollamaService.loadModel()
            
            // Cancel progress monitoring
            progressTask.cancel()
            
            // Model loaded successfully - the parent view should handle navigation
            loadingProgress = 1.0
            
            // Notify the chat view model to check connection again
            NotificationCenter.default.post(name: NSNotification.Name("ModelLoadedSuccessfully"), object: nil)
        } catch {
            status = .error("Failed to load model")
            subtitle = "Check your internet connection and try again"
        }
    }
    
    func retry() async {
        await startSetup()
    }
    
    func installOllama() async {
        do {
            try await installer.performCompleteSetup()
            // After installation, retry setup
            await startSetup()
        } catch {
            status = .error("Installation failed")
            subtitle = "Please install Ollama manually"
        }
    }
    
    func openTerminalForManualStart() {
        if let url = URL(string: "x-terminal://ollama serve") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: open Terminal app
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }
}