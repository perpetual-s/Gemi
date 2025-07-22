import Foundation
import Combine

/// Model setup service for Ollama integration
/// Verifies Ollama is running and model is ready
@MainActor
class SimplifiedModelSetupService: ObservableObject {
    @Published var currentStep: SetupStep = .checkingModel
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = "Initializing..."
    @Published var isComplete: Bool = false
    @Published var error: SetupError?
    
    private let chatService = OllamaChatService.shared
    
    enum SetupStep: String, CaseIterable {
        case checkingModel = "Checking Model"
        case loadingModel = "Loading Model"
        case complete = "Complete"
        
        var description: String {
            switch self {
            case .checkingModel:
                return "Verifying Gemma 3n is available..."
            case .loadingModel:
                return "Initializing Gemma 3n model..."
            case .complete:
                return "All set! Gemi is ready to use."
            }
        }
        
        var icon: String {
            switch self {
            case .checkingModel: return "magnifyingglass"
            case .loadingModel: return "cpu"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }
    
    enum SetupError: LocalizedError, Equatable {
        case modelNotFound
        case loadFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "Gemma 3n model not found in Ollama"
            case .loadFailed(let reason):
                return "Failed to initialize model: \(reason)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .modelNotFound:
                return "Please run 'ollama run gemma3n:latest' in Terminal"
            case .loadFailed:
                return "Make sure Ollama is running with 'ollama serve'"
            }
        }
    }
    
    func startSetup() {
        Task {
            await performSetup()
        }
    }
    
    private func performSetup() async {
        do {
            // Step 1: Check if model is already loaded
            currentStep = .checkingModel
            statusMessage = "Checking Ollama connection..."
            progress = 0.2
            
            let health = await chatService.health()
            if health.modelLoaded {
                // Model already loaded
                currentStep = .complete
                statusMessage = "Gemma 3n is ready!"
                progress = 1.0
                isComplete = true
                return
            }
            
            // Step 2: Verify model exists in Ollama
            let isModelReady = await chatService.checkModelReady()
            if !isModelReady {
                throw SetupError.modelNotFound
            }
            
            progress = 0.4
            statusMessage = "Found Gemma 3n, initializing..."
            
            // Step 3: Initialize the model
            currentStep = .loadingModel
            statusMessage = "Starting Gemma 3n model..."
            progress = 0.6
            
            try await chatService.loadModel()
            
            // Step 4: Complete
            currentStep = .complete
            statusMessage = "Gemi is ready to use!"
            progress = 1.0
            isComplete = true
            
        } catch {
            self.error = error as? SetupError ?? SetupError.loadFailed(error.localizedDescription)
            statusMessage = "Setup failed: \(error.localizedDescription)"
        }
    }
    
    /// Get the current step index for progress tracking
    var currentStepIndex: Int {
        SetupStep.allCases.firstIndex(of: currentStep) ?? 0
    }
    
    /// Get total number of steps
    var totalSteps: Int {
        SetupStep.allCases.count
    }
}