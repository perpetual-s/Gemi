import SwiftUI

/// First-time setup view for Ollama integration
struct OllamaSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var setupManager = OllamaSetupManager()
    @State private var currentStep = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain")
                    .font(.largeTitle)
                    .foregroundColor(Theme.Colors.primaryAccent)
                
                VStack(alignment: .leading) {
                    Text("Setting up AI Features")
                        .font(Theme.Typography.largeTitle)
                    Text("One-time setup for Gemi's AI companion")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
            }
            .padding(Theme.largeSpacing)
            
            Divider()
            
            // Progress indicator
            ProgressView(value: Double(currentStep), total: 3)
                .progressViewStyle(.linear)
                .padding(.horizontal, Theme.largeSpacing)
                .padding(.vertical, Theme.spacing)
            
            // Content
            VStack {
                switch currentStep {
                case 0:
                    checkingOllamaView
                case 1:
                    downloadingModelView
                case 2:
                    completionView
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Theme.largeSpacing)
            
            // Actions
            HStack {
                if setupManager.hasError {
                    Button("Retry") {
                        setupManager.retry()
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                if currentStep == 2 {
                    Button("Get Started") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                } else if setupManager.canSkip {
                    Button("Skip Setup") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.largeSpacing)
        }
        .frame(width: 600, height: 500)
        .background(Theme.Colors.windowBackground)
        .onAppear {
            setupManager.startSetup()
        }
        .onChange(of: setupManager.currentState) {
            withAnimation(Theme.smoothAnimation) {
                switch setupManager.currentState {
                case .checkingOllama:
                    currentStep = 0
                case .downloadingModel, .creatingCompanion:
                    currentStep = 1
                case .completed:
                    currentStep = 2
                case .error:
                    break
                }
            }
        }
    }
    
    private var checkingOllamaView: some View {
        VStack(spacing: Theme.largeSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.tertiaryText)
            
            Text("Checking for Ollama...")
                .font(Theme.Typography.title)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            
            Text(setupManager.statusMessage)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
    
    private var downloadingModelView: some View {
        VStack(spacing: Theme.largeSpacing) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.primaryAccent)
            
            Text("Setting up Gemma 3n")
                .font(Theme.Typography.title)
            
            VStack(spacing: Theme.spacing) {
                ProgressView(value: setupManager.downloadProgress)
                    .progressViewStyle(.linear)
                
                HStack {
                    Text(setupManager.statusMessage)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Spacer()
                    
                    if setupManager.downloadProgress > 0 {
                        Text("\(Int(setupManager.downloadProgress * 100))%")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
            }
            
            Text("This may take a few minutes depending on your internet connection.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
                .multilineTextAlignment(.center)
        }
    }
    
    private var completionView: some View {
        VStack(spacing: Theme.largeSpacing) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("AI Features Ready!")
                .font(Theme.Typography.title)
            
            Text("Gemi is now ready to be your AI companion. You can start chatting and get personalized insights from your journal entries.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                Label("Chat with Gemi about your thoughts", systemImage: "bubble.left.and.bubble.right")
                Label("Get personalized reflection prompts", systemImage: "lightbulb")
                Label("Discover patterns in your journal", systemImage: "chart.line.uptrend.xyaxis")
            }
            .font(Theme.Typography.body)
            .padding()
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.cornerRadius)
        }
    }
}

/// Manages the Ollama setup process
@MainActor
final class OllamaSetupManager: ObservableObject {
    @Published var currentState: SetupState = .checkingOllama
    @Published var statusMessage = "Initializing..."
    @Published var downloadProgress: Double = 0.0
    @Published var hasError = false
    @Published var canSkip = false
    
    private let processManager = OllamaProcessManager.shared
    private let ollamaService = OllamaService.shared
    private let companionService = CompanionModelService.shared
    
    enum SetupState: Equatable {
        case checkingOllama
        case downloadingModel
        case creatingCompanion
        case completed
        case error(String)
    }
    
    func startSetup() {
        Task {
            await performSetup()
        }
    }
    
    func retry() {
        hasError = false
        currentState = .checkingOllama
        Task {
            await performSetup()
        }
    }
    
    private func performSetup() async {
        do {
            // Step 1: Check if Ollama is installed
            currentState = .checkingOllama
            statusMessage = "Checking if Ollama is installed..."
            
            let isInstalled = await processManager.isOllamaInstalled()
            if !isInstalled {
                statusMessage = "Ollama is not installed. Please download it from ollama.ai"
                hasError = true
                canSkip = true
                currentState = .error("Ollama not installed")
                return
            }
            
            // Step 2: Ensure Ollama is running
            statusMessage = "Starting Ollama service..."
            try await processManager.ensureOllamaRunning()
            
            // Step 3: Check if model exists
            let hasModel = try await ollamaService.checkHealth()
            if !hasModel {
                currentState = .downloadingModel
                statusMessage = "Downloading Gemma 3n model..."
                
                // Pull model with progress tracking
                try await ollamaService.pullModel("gemma3n:latest") { [weak self] progress, status in
                    Task { @MainActor in
                        self?.downloadProgress = progress
                        self?.statusMessage = status
                    }
                }
            }
            
            // Step 4: Create companion model
            currentState = .creatingCompanion
            statusMessage = "Creating your AI companion..."
            try await companionService.setupCompanionModel()
            
            // Step 5: Complete
            currentState = .completed
            statusMessage = "Setup completed successfully!"
            
            // Save setup completion
            UserDefaults.standard.set(true, forKey: "OllamaSetupCompleted")
            
        } catch {
            hasError = true
            statusMessage = error.localizedDescription
            currentState = .error(error.localizedDescription)
            
            // Allow skipping if it's not a critical error
            if error.localizedDescription.contains("not installed") {
                canSkip = true
            }
        }
    }
}

// MARK: - Helper to check if setup is needed

extension UserDefaults {
    var needsOllamaSetup: Bool {
        !bool(forKey: "OllamaSetupCompleted")
    }
}