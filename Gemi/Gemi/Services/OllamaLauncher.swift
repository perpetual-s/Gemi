import Foundation
import AppKit
import os.log

/// Coordinates Ollama server lifecycle management
@MainActor
final class OllamaLauncher: ObservableObject {
    static let shared = OllamaLauncher()
    
    @Published var status: LaunchStatus = .unknown
    @Published var errorMessage: String?
    @Published var isModelReady = false
    
    private let logger = Logger(subsystem: "com.gemi", category: "OllamaLauncher")
    private let processManager = OllamaProcessManager.shared
    private let ollamaService = OllamaService.shared
    private let companionService = CompanionModelService.shared
    
    enum LaunchStatus {
        case unknown
        case checking
        case notInstalled
        case launching
        case running
        case modelDownloading
        case ready
        case error
    }
    
    private init() {}
    
    /// Check and launch Ollama with automatic setup
    func checkAndLaunchOllama() async {
        logger.info("Starting Ollama check and launch sequence")
        
        status = .checking
        errorMessage = nil
        
        // Check if Ollama is installed
        guard await processManager.isOllamaInstalled() else {
            logger.error("Ollama not found")
            status = .notInstalled
            errorMessage = "Ollama is not installed. Please install from https://ollama.ai"
            return
        }
        
        // Check if already running
        if await processManager.isOllamaServerRunning() {
            logger.info("Ollama server is already running")
            status = .running
            await checkModelAvailability()
            return
        }
        
        // Launch Ollama
        status = .launching
        do {
            try await processManager.ensureOllamaRunning()
            
            // Wait for server to be ready
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Verify it's running
            if await processManager.isOllamaServerRunning() {
                status = .running
                await checkModelAvailability()
            } else {
                throw OllamaProcessError.serverNotResponding
            }
        } catch {
            logger.error("Failed to launch Ollama: \(error)")
            status = .error
            errorMessage = error.localizedDescription
        }
    }
    
    /// Check if the required models are available
    private func checkModelAvailability() async {
        do {
            let hasModel = try await ollamaService.checkHealth()
            
            if hasModel {
                // Check if companion model exists
                await setupCompanionModel()
            } else {
                // Need to download the model
                status = .modelDownloading
                await downloadRequiredModels()
            }
        } catch {
            logger.error("Failed to check model availability: \(error)")
            status = .error
            errorMessage = "Failed to check models: \(error.localizedDescription)"
        }
    }
    
    /// Download required models
    private func downloadRequiredModels() async {
        do {
            // Pull the base model
            try await ollamaService.pullModel("gemma3n") { progress, status in
                self.logger.info("Download progress: \(progress) - \(status)")
            }
            
            // Pull embedding model
            try await ollamaService.pullModel("nomic-embed-text") { progress, status in
                self.logger.info("Embedding model progress: \(progress) - \(status)")
            }
            
            await setupCompanionModel()
        } catch {
            logger.error("Failed to download models: \(error)")
            status = .error
            errorMessage = "Failed to download models: \(error.localizedDescription)"
        }
    }
    
    /// Setup the companion model
    private func setupCompanionModel() async {
        do {
            // Create or update the companion model
            try await companionService.setupCompanionModel()
            
            status = .ready
            isModelReady = true
            logger.info("Ollama and companion model are ready")
        } catch {
            logger.error("Failed to setup companion model: \(error)")
            // Don't fail completely - can still use base model
            status = .ready
            isModelReady = true
        }
    }
    
    /// Stop Ollama server
    func stopOllama() async {
        await processManager.stopOllama()
        status = .unknown
        isModelReady = false
    }
}