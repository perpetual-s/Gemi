import Foundation
import AppKit
import os.log

/// Manages the bundled GemiServer.app lifecycle
@MainActor
class BundledServerManager: ObservableObject {
    static let shared = BundledServerManager()
    
    // MARK: - Published Properties
    
    @Published var serverStatus: ServerStatus = .notRunning
    @Published var statusMessage: String = ""
    @Published var modelDownloadProgress: Double = 0.0
    
    // MARK: - Types
    
    enum ServerStatus: Equatable {
        case notRunning
        case launching
        case loading
        case downloadingModel(progress: Double)
        case ready
        case error(String)
        
        var isOperational: Bool {
            switch self {
            case .ready, .downloadingModel:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var serverProcess: Process?
    private let serverPort = 11435
    private let logger = Logger(subsystem: "com.gemi", category: "BundledServerManager")
    private var healthCheckTimer: Timer?
    private var launchTask: Task<Void, Error>?
    
    // MARK: - Initialization
    
    private init() {
        // Check server status on init
        Task {
            await checkInitialStatus()
        }
    }
    
    // MARK: - Public Methods
    
    /// Start the bundled server if not already running
    func startServer() async throws {
        guard serverStatus == .notRunning || serverStatus == .error("") else {
            logger.info("Server already starting or running")
            return
        }
        
        serverStatus = .launching
        statusMessage = "Starting Gemi AI server..."
        
        // Cancel any existing launch task
        launchTask?.cancel()
        
        // Create new launch task
        launchTask = Task {
            try await performServerLaunch()
        }
        
        try await launchTask!.value
    }
    
    /// Stop the server gracefully
    func stopServer() {
        logger.info("Stopping server...")
        
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        
        if let process = serverProcess {
            process.terminate()
            serverProcess = nil
        }
        
        serverStatus = .notRunning
        statusMessage = "Server stopped"
    }
    
    /// Check if server is healthy
    func checkHealth() async -> Bool {
        do {
            let url = URL(string: "http://127.0.0.1:\(serverPort)/api/health")!
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            // Parse health response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String,
               let modelLoaded = json["model_loaded"] as? Bool {
                
                if status == "healthy" && modelLoaded {
                    return true
                }
                
                // Check for model download progress
                if let downloadProgress = json["download_progress"] as? Double {
                    await MainActor.run {
                        self.modelDownloadProgress = downloadProgress
                        self.serverStatus = .downloadingModel(progress: downloadProgress)
                        self.statusMessage = "Downloading Gemma 3n model: \(Int(downloadProgress * 100))%"
                    }
                }
            }
            
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func checkInitialStatus() async {
        if await checkHealth() {
            serverStatus = .ready
            statusMessage = "Server already running"
        }
    }
    
    private func performServerLaunch() async throws {
        // Find the bundled server
        let serverURL = locateServerBundle()
        
        guard FileManager.default.fileExists(atPath: serverURL.path) else {
            let error = "GemiServer.app not found. Please reinstall Gemi."
            serverStatus = .error(error)
            statusMessage = error
            throw ServerError.serverNotFound
        }
        
        // Prepare the process
        let process = Process()
        process.executableURL = serverURL.appendingPathComponent("Contents/MacOS/GemiServer")
        
        // Set environment
        var environment = ProcessInfo.processInfo.environment
        environment["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
        environment["HF_HOME"] = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Gemi/Models").path
        process.environment = environment
        
        // Capture output for debugging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Handle output asynchronously
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                self?.logger.debug("Server output: \(output)")
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let error = String(data: data, encoding: .utf8) {
                self?.logger.error("Server error: \(error)")
            }
        }
        
        // Launch the process
        do {
            try process.run()
            serverProcess = process
            logger.info("Server process launched")
            
            // Wait for server to be ready
            await waitForServerReady()
            
        } catch {
            let errorMsg = "Failed to launch server: \(error.localizedDescription)"
            serverStatus = .error(errorMsg)
            statusMessage = errorMsg
            logger.error("\(errorMsg)")
            throw ServerError.launchFailed(error.localizedDescription)
        }
    }
    
    private func waitForServerReady() async {
        serverStatus = .loading
        statusMessage = "Waiting for server to initialize..."
        
        // Start periodic health checks
        startHealthCheckTimer()
        
        // Wait up to 60 seconds for initial startup
        for attempt in 1...60 {
            if await checkHealth() {
                serverStatus = .ready
                statusMessage = "Gemma 3n ready!"
                logger.info("Server ready after \(attempt) seconds")
                return
            }
            
            // Update status message based on timing
            if attempt < 5 {
                statusMessage = "Starting server..."
            } else if attempt < 15 {
                statusMessage = "Loading AI model..."
            } else {
                statusMessage = "Downloading model (first run only)..."
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Check if task was cancelled
            if Task.isCancelled {
                serverStatus = .error("Server startup cancelled")
                return
            }
        }
        
        // Timeout
        serverStatus = .error("Server startup timeout")
        statusMessage = "Server failed to start. Please check logs."
        logger.error("Server startup timeout after 60 seconds")
    }
    
    private func startHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                guard let self = self else { return }
                
                let isHealthy = await self.checkHealth()
                
                await MainActor.run {
                    if isHealthy && self.serverStatus != .ready {
                        self.serverStatus = .ready
                        self.statusMessage = "Server healthy"
                    } else if !isHealthy && self.serverStatus == .ready {
                        self.serverStatus = .error("Server became unresponsive")
                        self.statusMessage = "Server connection lost"
                    }
                }
            }
        }
    }
    
    private func locateServerBundle() -> URL {
        // Check multiple locations in priority order
        let locations = [
            // 1. Same directory as Gemi.app (for DMG distribution)
            Bundle.main.bundleURL.deletingLastPathComponent()
                .appendingPathComponent("GemiServer.app"),
            
            // 2. In /Applications (standard installation)
            URL(fileURLWithPath: "/Applications/GemiServer.app"),
            
            // 3. In ~/Applications (user installation)
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications/GemiServer.app"),
            
            // 4. Development location (for testing)
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Documents/project-Gemi/python-inference-server/dist/GemiServer.app")
        ]
        
        // Find first existing location
        for location in locations {
            if FileManager.default.fileExists(atPath: location.path) {
                logger.info("Found GemiServer at: \(location.path)")
                return location
            }
        }
        
        // Default to /Applications
        logger.warning("GemiServer.app not found in expected locations")
        return URL(fileURLWithPath: "/Applications/GemiServer.app")
    }
}

// MARK: - Error Types

enum ServerError: LocalizedError {
    case serverNotFound
    case launchFailed(String)
    case connectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .serverNotFound:
            return "GemiServer.app not found. Please reinstall Gemi."
        case .launchFailed(let reason):
            return "Failed to launch server: \(reason)"
        case .connectionFailed(let reason):
            return "Failed to connect to server: \(reason)"
        }
    }
}

// MARK: - Health Response Model

private struct ServerHealthResponse: Codable {
    let status: String
    let model_loaded: Bool
    let download_progress: Double?
    let mps_available: Bool?
}