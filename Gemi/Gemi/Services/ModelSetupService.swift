import Foundation
import AppKit

/// Simplified model setup service for bundled deployment
@MainActor
class ModelSetupService: ObservableObject {
    @Published var currentStep: SetupStep = .checkingServer
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = "Initializing..."
    @Published var isComplete: Bool = false
    @Published var error: SetupError?
    
    enum SetupStep: String, CaseIterable {
        case checkingServer = "Checking Server"
        case launchingServer = "Launching Server"
        case downloadingModel = "Downloading Model"
        case complete = "Complete"
        
        var description: String {
            switch self {
            case .checkingServer:
                return "Looking for Gemi AI server..."
            case .launchingServer:
                return "Starting the AI server..."
            case .downloadingModel:
                return "Downloading Gemma 3n model..."
            case .complete:
                return "Setup complete! Gemma 3n is ready."
            }
        }
        
        var icon: String {
            switch self {
            case .checkingServer: return "magnifyingglass"
            case .launchingServer: return "play.circle"
            case .downloadingModel: return "icloud.and.arrow.down"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }
    
    enum SetupError: LocalizedError {
        case serverNotFound
        case launchFailed(String)
        case downloadFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .serverNotFound:
                return "GemiServer.app not found"
            case .launchFailed(let reason):
                return "Failed to start server: \(reason)"
            case .downloadFailed(let reason):
                return "Model download failed: \(reason)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .serverNotFound:
                return "Please reinstall Gemi from the DMG installer"
            case .launchFailed:
                return "Try restarting Gemi or check if port 11435 is in use"
            case .downloadFailed:
                return "Check your internet connection and try again"
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
            // Step 1: Check if server is already running
            currentStep = .checkingServer
            statusMessage = "Checking for existing server..."
            progress = 0.1
            
            if await BundledServerManager.shared.checkHealth() {
                // Server already running
                currentStep = .complete
                statusMessage = "Server already running!"
                progress = 1.0
                isComplete = true
                return
            }
            
            // Step 2: Launch the bundled server
            currentStep = .launchingServer
            statusMessage = "Starting Gemi AI server..."
            progress = 0.3
            
            try await BundledServerManager.shared.startServer()
            
            // Step 3: Monitor model download if needed
            currentStep = .downloadingModel
            progress = 0.5
            
            // Subscribe to server status updates
            await monitorServerStatus()
            
        } catch let setupError as SetupError {
            self.error = setupError
            statusMessage = setupError.localizedDescription
        } catch {
            self.error = .launchFailed(error.localizedDescription)
            statusMessage = error.localizedDescription
        }
    }
    
    private func monitorServerStatus() async {
        // Set up observation of server status changes
        let serverManager = BundledServerManager.shared
        
        // Create a task that monitors server status
        Task { @MainActor in
            // Monitor status changes with async loop
            while !self.isComplete && self.error == nil {
                switch serverManager.serverStatus {
                case .ready:
                    self.currentStep = .complete
                    self.statusMessage = "Setup complete!"
                    self.progress = 1.0
                    self.isComplete = true
                    return
                    
                case .downloadingModel(let downloadProgress):
                    self.currentStep = .downloadingModel
                    self.statusMessage = "Downloading Gemma 3n model (\(Int(downloadProgress * 100))%)"
                    self.progress = 0.5 + (downloadProgress * 0.5)
                    
                case .error(let errorMsg):
                    self.error = SetupError.launchFailed(errorMsg)
                    self.statusMessage = errorMsg
                    return
                    
                case .loading:
                    self.statusMessage = "Loading AI model..."
                    
                case .launching:
                    self.statusMessage = "Starting server..."
                    
                default:
                    break
                }
                
                // Wait a bit before checking again
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        // Don't block here - return immediately to keep UI responsive
        statusMessage = "Starting Gemi AI server..."
    }
}

// ModelSetupHelper already exists in Helpers/ModelSetupHelper.swift