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
    
    /// Restart the server gracefully
    func restartServer() async throws {
        logger.info("Restarting server...")
        stopServer()
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        try await startServer()
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
            var request = URLRequest(url: url)
            request.timeoutInterval = 2.0 // 2 second timeout
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
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
                        if downloadProgress < 0 {
                            // Error state
                            self.serverStatus = .error("Model loading failed")
                            self.statusMessage = "Failed to load AI model. Check server logs."
                        } else {
                            self.serverStatus = .downloadingModel(progress: downloadProgress)
                            self.statusMessage = "Downloading Gemma 3n model: \(Int(downloadProgress * 100))%"
                        }
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
        // Find the bundled GemiServer.app
        let serverURL = locateServerBundle()
        
        logger.info("Attempting to launch server from: \(serverURL.path)")
        
        guard FileManager.default.fileExists(atPath: serverURL.path) else {
            let error = "GemiServer.app not found at \(serverURL.path). Please reinstall Gemi."
            serverStatus = .error(error)
            statusMessage = error
            logger.error("Server not found at \(serverURL.path)")
            throw ServerError.serverNotFound
        }
        
        // Launch the server executable directly
        let executablePath = serverURL.appendingPathComponent("Contents/MacOS/GemiServer")
        
        guard FileManager.default.fileExists(atPath: executablePath.path) else {
            let error = "GemiServer executable not found"
            serverStatus = .error(error)
            statusMessage = error
            logger.error("\(error)")
            throw ServerError.serverNotFound
        }
        
        logger.info("Server executable found at: \(executablePath.path)")
        
        try await launchServerWithExecutable(executableURL: executablePath)
    }
    
    private func launchServerWithExecutable(executableURL: URL) async throws {
        // Prepare the process
        let process = Process()
        process.executableURL = executableURL
        
        // Set environment
        var environment = ProcessInfo.processInfo.environment
        environment["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
        let modelPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Gemi/Models").path
        environment["HF_HOME"] = modelPath
        environment["TRANSFORMERS_CACHE"] = modelPath
        environment["TORCH_HOME"] = modelPath
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
                // Check for specific messages
                if output.contains("Downloading") || output.contains("download") {
                    Task { @MainActor in
                        self?.statusMessage = "Downloading Gemma 3n model (~8GB)..."
                    }
                }
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let error = String(data: data, encoding: .utf8) {
                self?.logger.error("Server error: \(error)")
                // Capture critical errors
                if error.contains("Permission denied") || error.contains("cannot execute") {
                    Task { @MainActor in
                        self?.serverStatus = .error("Permission error: Server cannot execute")
                        self?.statusMessage = "Server permission error. Try reinstalling Gemi."
                    }
                }
            }
        }
        
        // Launch the process
        do {
            logger.info("Attempting to launch process...")
            try process.run()
            serverProcess = process
            logger.info("Server process launched with PID: \(process.processIdentifier)")
            
            // Monitor process status
            Task {
                process.waitUntilExit()
                let exitCode = process.terminationStatus
                let reason = process.terminationReason
                
                await MainActor.run {
                    if exitCode != 0 {
                        self.logger.error("Server process terminated with exit code: \(exitCode), reason: \(reason.rawValue)")
                        if exitCode == 137 {
                            self.serverStatus = .error("Server killed by system (code signing or sandbox issue)")
                            self.statusMessage = "Server was terminated. This is usually due to code signing issues."
                        } else {
                            self.serverStatus = .error("Server exited with code \(exitCode)")
                            self.statusMessage = "Server process failed to start properly."
                        }
                    }
                }
            }
            
            // Wait for server to be ready
            await waitForServerReady()
            
        } catch {
            let nsError = error as NSError
            let errorMsg = "Failed to launch server: \(error.localizedDescription) (Code: \(nsError.code), Domain: \(nsError.domain))"
            serverStatus = .error(errorMsg)
            statusMessage = errorMsg
            logger.error("\(errorMsg)")
            logger.error("Full error: \(error)")
            throw ServerError.launchFailed(error.localizedDescription)
        }
    }
    
    private func waitForServerReady() async {
        serverStatus = .loading
        statusMessage = "Waiting for server to initialize..."
        
        // Start periodic health checks
        startHealthCheckTimer()
        
        // Don't block here - let the health check timer handle status updates
        // The UI will remain responsive and update based on server status changes
        
        // Just do a quick initial check
        for attempt in 1...10 {
            if await checkHealth() {
                serverStatus = .ready
                statusMessage = "Gemma 3n ready!"
                logger.info("Server ready after \(attempt) seconds")
                return
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            if Task.isCancelled {
                serverStatus = .error("Server startup cancelled")
                return
            }
        }
        
        // After initial quick checks, just set status to loading
        // The health check timer will continue monitoring
        statusMessage = "Server is starting up. This may take a few minutes on first run..."
        logger.info("Server not immediately ready, continuing with background monitoring")
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
                        
                        // Attempt automatic recovery
                        Task {
                            self.logger.warning("Server became unresponsive, attempting restart...")
                            do {
                                try await self.restartServer()
                                self.logger.info("Server restarted successfully")
                            } catch {
                                self.logger.error("Failed to restart server: \(error)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func locateServerBundle() -> URL {
        // Check for bundled GemiServer.app in priority order
        let locations = [
            // 1. Inside Gemi.app bundle (primary location)
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/GemiServer.app"),
            
            // 2. Development location (for testing)
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Documents/project-Gemi/python-inference-server/dist/GemiServer.app")
        ]
        
        // Find first existing location
        for location in locations {
            if FileManager.default.fileExists(atPath: location.path) {
                logger.info("Using GemiServer at: \(location.path)")
                return location
            }
        }
        
        // Default to expected location
        logger.error("GemiServer.app not found in any expected location")
        return locations.first!
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