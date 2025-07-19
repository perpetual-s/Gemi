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
    @Published var downloadProgress: Double = 0.0
    @Published var downloadedBytes: Int64 = 0
    @Published var totalDownloadBytes: Int64 = 0
    @Published var currentDownloadFile: String = ""
    @Published var downloaderState: UltimateModelDownloader.DownloadState = .notStarted
    @Published var downloadStartTime: Date?
    @Published var downloadSpeed: Double = 0
    
    private let chatService = NativeChatService.shared
    let modelDownloader = UltimateModelDownloader()  // Using the most reliable downloader
    
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
                return "Download configuration error"
            }
        }
        
        var userFriendlyMessage: String {
            switch self {
            case .modelNotFound:
                return "Model files not found. Please download the model first."
            case .downloadFailed(let reason):
                // Clean up technical messages for users
                if reason.contains("error page") {
                    return "The download server returned an error. This is usually temporary - please try again."
                } else if reason.contains("Size mismatch") {
                    return "Downloaded file was corrupted. The download will retry automatically."
                } else if reason.contains("HTTP 401") || reason.contains("HTTP 403") {
                    return "Access error. The model configuration may need updating."
                } else if reason.contains("network") || reason.contains("connection") {
                    return "Network connection lost. Please check your internet connection."
                } else {
                    return reason
                        .replacingOccurrences(of: "authentication", with: "connection")
                        .replacingOccurrences(of: "Authentication", with: "Connection")
                }
            case .loadFailed:
                return "Model setup encountered an issue. Please try again."
            case .authenticationRequired:
                return "Connection issue. Please check your internet and try again."
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
                return "There was a problem accessing the model. Please try again later."
            }
        }
    }
    
    func startSetup() {
        Task {
            await performSetup()
        }
    }
    
    func resumeDownload() async {
        do {
            currentStep = .downloadingModel
            statusMessage = "Resuming download..."
            try await modelDownloader.startDownload()
        } catch {
            self.error = SetupError.downloadFailed(error.localizedDescription)
            statusMessage = "Failed to resume download: \(error.localizedDescription)"
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
                statusMessage = "Preparing to download Gemma 3n model (5.8 GB)..."
                progress = 0.2
                
                // Set up observers for download progress
                let downloadObserver = modelDownloader.$downloadState.sink { [weak self] state in
                    guard let self = self else { return }
                    
                    self.downloaderState = state
                    
                    switch state {
                    case .preparing:
                        self.statusMessage = "Preparing download..."
                    case .downloading(let file, let progress):
                        let percent = Int(progress * 100)
                        self.statusMessage = "Downloading \(file)... \(percent)%\n⏱ This may take 10-30 minutes depending on your connection"
                        self.progress = 0.2 + (progress * 0.6) // Scale to 20-80% of total progress
                        self.downloadProgress = progress
                        self.currentDownloadFile = file
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
                
                let bytesObserver = modelDownloader.$bytesDownloaded.sink { [weak self] bytes in
                    self?.downloadedBytes = bytes
                }
                
                let totalBytesObserver = modelDownloader.$totalBytes.sink { [weak self] total in
                    self?.totalDownloadBytes = total
                }
                
                _ = modelDownloader.$downloadStartTime.sink { [weak self] startTime in
                    self?.downloadStartTime = startTime
                }
                
                _ = modelDownloader.$downloadSpeed.sink { [weak self] speed in
                    self?.downloadSpeed = speed
                }
                
                try await modelDownloader.startDownload()
                
                downloadObserver.cancel()
                bytesObserver.cancel()
                totalBytesObserver.cancel()
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
            statusMessage = setupError.userFriendlyMessage
        } catch let modelError as ModelError {
            switch modelError {
            case .authenticationRequired:
                self.error = .downloadFailed("Connection issue. Please check your internet and try again.")
                statusMessage = "Connection issue - please try again"
            case .downloadFailed(let reason):
                // Clean up technical jargon for users
                let userFriendlyReason = reason
                    .replacingOccurrences(of: "HTTP 401", with: "Connection error")
                    .replacingOccurrences(of: "HTTP 403", with: "Access error")
                    .replacingOccurrences(of: "authentication", with: "connection")
                    .replacingOccurrences(of: "Authentication", with: "Connection")
                self.error = .downloadFailed(userFriendlyReason)
                statusMessage = userFriendlyReason
            case .modelNotFound:
                self.error = .downloadFailed("Model files not found. Please ensure the download completed successfully.")
                statusMessage = "Model files not ready"
            case .invalidFormat(let reason):
                self.error = .downloadFailed("Model files appear corrupted: \(reason). Please delete the model folder and download again.")
                statusMessage = "Invalid model format"
            default:
                self.error = .downloadFailed("Setup failed. Please try deleting the model folder and downloading again.")
                statusMessage = "Setup failed - please retry"
            }
        } catch {
            // Generic error - provide helpful message
            print("❌ Setup failed with error: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error details: \(error.localizedDescription)")
            
            // More specific error message based on the actual error
            let errorMessage: String
            if error.localizedDescription.contains("401") || error.localizedDescription.contains("403") {
                errorMessage = "Authentication failed. Please ensure you have accepted the Gemma model license at huggingface.co"
            } else if error.localizedDescription.contains("network") || error.localizedDescription.contains("connection") {
                errorMessage = "Network connection failed. Please check your internet and try again."
            } else {
                errorMessage = "Download failed: \(error.localizedDescription)"
            }
            
            self.error = .downloadFailed(errorMessage)
            statusMessage = errorMessage
        }
    }
    
    // Removed monitorServerStatus as it's no longer needed with native implementation
}

// ModelSetupHelper already exists in Helpers/ModelSetupHelper.swift