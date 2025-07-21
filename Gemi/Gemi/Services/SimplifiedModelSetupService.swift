import Foundation
import Combine

/// Simplified model setup service for bundled MLX model
/// No downloading - just validation and loading
@MainActor
class SimplifiedModelSetupService: ObservableObject {
    @Published var currentStep: SetupStep = .checkingModel
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = "Initializing..."
    @Published var isComplete: Bool = false
    @Published var error: SetupError?
    
    private let chatService = NativeChatService.shared
    
    enum SetupStep: String, CaseIterable {
        case checkingModel = "Checking Model"
        case loadingModel = "Loading Model"
        case complete = "Complete"
        
        var description: String {
            switch self {
            case .checkingModel:
                return "Checking bundled Gemma 3n model..."
            case .loadingModel:
                return "Loading model into memory..."
            case .complete:
                return "Setup complete! Gemma 3n is ready."
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
                return "Bundled model not found"
            case .loadFailed(let reason):
                return "Failed to load model: \(reason)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .modelNotFound:
                return "Please reinstall Gemi to restore the bundled model"
            case .loadFailed:
                return "Try restarting Gemi to free up memory"
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
            statusMessage = "Checking for bundled model..."
            progress = 0.2
            
            let health = await chatService.health()
            if health.modelLoaded {
                // Model already loaded
                currentStep = .complete
                statusMessage = "Model already loaded!"
                progress = 1.0
                isComplete = true
                return
            }
            
            // Step 2: Verify bundled model exists
            let isModelReady = await chatService.checkModelReady()
            if !isModelReady {
                throw SetupError.modelNotFound
            }
            
            progress = 0.4
            statusMessage = "Found bundled model, preparing to load..."
            
            // Step 3: Load the model
            currentStep = .loadingModel
            statusMessage = "Loading Gemma 3n model into memory..."
            progress = 0.6
            
            try await chatService.loadModel()
            
            // Step 4: Complete
            currentStep = .complete
            statusMessage = "Model loaded successfully!"
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