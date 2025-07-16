import Foundation
import AppKit
import Combine

/// Model setup service for native MLX deployment
@MainActor
class ModelSetupService: ObservableObject {
    @Published var currentStep: SetupStep = .checkingModel
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = "Initializing..."
    @Published var isComplete: Bool = false
    @Published var error: SetupError?
    
    private let chatService = NativeChatService.shared
    private let modelDownloader = ModelDownloader()
    
    enum SetupStep: String, CaseIterable {
        case checkingModel = "Checking Model"
        case downloadingModel = "Downloading Model"
        case loadingModel = "Loading Model"
        case complete = "Complete"
        
        var description: String {
            switch self {
            case .checkingModel:
                return "Checking for Gemma 3n model..."
            case .downloadingModel:
                return "Downloading Gemma 3n model..."
            case .loadingModel:
                return "Loading model into memory..."
            case .complete:
                return "Setup complete! Gemma 3n is ready."
            }
        }
        
        var icon: String {
            switch self {
            case .checkingModel: return "magnifyingglass"
            case .downloadingModel: return "icloud.and.arrow.down"
            case .loadingModel: return "cpu"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }
    
    enum SetupError: LocalizedError, Equatable {
        case modelNotFound
        case downloadFailed(String)
        case loadFailed(String)
        case authenticationRequired
        
        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "Gemma 3n model not found"
            case .downloadFailed(let reason):
                return "Model download failed: \(reason)"
            case .loadFailed(let reason):
                return "Failed to load model: \(reason)"
            case .authenticationRequired:
                return "HuggingFace authentication required"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .modelNotFound:
                return "The model will be downloaded automatically"
            case .downloadFailed(let reason):
                if reason.contains("401") || reason.contains("403") {
                    return "This model requires a HuggingFace token. Please add your token in the settings."
                }
                return "Check your internet connection and try again"
            case .loadFailed:
                return "Try restarting Gemi to free up memory"
            case .authenticationRequired:
                return "Gemma models are gated and require a HuggingFace token for access."
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
            statusMessage = "Checking for existing model..."
            progress = 0.1
            
            let health = await chatService.health()
            if health.modelLoaded {
                // Model already loaded
                currentStep = .complete
                statusMessage = "Model already loaded!"
                progress = 1.0
                isComplete = true
                return
            }
            
            // Step 2: Check if model needs downloading
            let isModelComplete = await ModelCache.shared.isModelComplete()
            if !isModelComplete {
                currentStep = .downloadingModel
                statusMessage = "Preparing to download Gemma 3n model (15.7 GB)..."
                progress = 0.2
                
                // Set up observer for download progress
                let downloadObserver = modelDownloader.$downloadState.sink { [weak self] state in
                    guard let self = self else { return }
                    
                    switch state {
                    case .preparing:
                        self.statusMessage = "Preparing download..."
                    case .downloading(let file, let progress):
                        self.statusMessage = "Downloading model files...\n⏱ This may take 20-60 minutes depending on your connection"
                        self.progress = 0.2 + (progress * 0.6) // Scale to 20-80% of total progress
                    case .verifying:
                        self.statusMessage = "Verifying downloaded files..."
                        self.progress = 0.85
                    case .completed:
                        self.statusMessage = "Download complete!"
                        self.progress = 0.9
                    case .failed(let reason):
                        self.statusMessage = "Download failed: \(reason)"
                    default:
                        break
                    }
                }
                
                try await modelDownloader.startDownload()
                downloadObserver.cancel()
            }
            
            // Step 3: Load the model
            currentStep = .loadingModel
            statusMessage = "Loading Gemma 3n into memory..."
            progress = 0.8
            
            try await chatService.loadModel()
            
            // Complete!
            currentStep = .complete
            statusMessage = "Setup complete!"
            progress = 1.0
            isComplete = true
            
        } catch let setupError as SetupError {
            self.error = setupError
            statusMessage = setupError.localizedDescription
        } catch let modelError as ModelError {
            switch modelError {
            case .authenticationRequired(let message):
                self.error = .authenticationRequired
                statusMessage = message
            case .downloadFailed(let reason):
                self.error = .downloadFailed(reason)
                statusMessage = reason
            default:
                self.error = .downloadFailed(modelError.localizedDescription)
                statusMessage = modelError.localizedDescription
            }
        } catch {
            // Check if it's an authentication error
            let errorMessage = error.localizedDescription
            if errorMessage.contains("401") || errorMessage.contains("403") || errorMessage.contains("Unauthorized") || errorMessage.contains("authentication") {
                self.error = .authenticationRequired
                statusMessage = "Authentication required"
            } else {
                self.error = .downloadFailed(error.localizedDescription)
                statusMessage = error.localizedDescription
            }
        }
    }
    
    // Removed monitorServerStatus as it's no longer needed with native implementation
}

// ModelSetupHelper already exists in Helpers/ModelSetupHelper.swift