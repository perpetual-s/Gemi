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
    private var hasRetriedAfter137 = false
    private var portCheckAttempts = 0
    
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
            
            // Give it 2 seconds to terminate gracefully
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if process.isRunning {
                    self?.logger.warning("Server didn't terminate gracefully, sending SIGKILL")
                    process.interrupt() // Try SIGINT first
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        if process.isRunning {
                            kill(process.processIdentifier, SIGKILL)
                        }
                    }
                }
            }
            
            serverProcess = nil
        }
        
        // Clean up any zombie processes
        cleanupZombieProcesses()
        
        serverStatus = .notRunning
        statusMessage = "Server stopped"
        hasRetriedAfter137 = false
        portCheckAttempts = 0
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
                    await MainActor.run {
                        self.serverStatus = .ready
                        self.statusMessage = "Gemma 3n ready!"
                        self.modelDownloadProgress = 1.0
                    }
                    return true
                }
                
                // Check for model download progress
                if let downloadProgress = json["download_progress"] as? Double {
                    await MainActor.run {
                        // Handle the case where server reports 0.9 for cached models
                        if downloadProgress >= 0.9 && !modelLoaded {
                            // Model is cached but still loading
                            self.serverStatus = .loading
                            self.statusMessage = "Loading Gemma 3n model from cache..."
                            self.modelDownloadProgress = downloadProgress
                        } else if downloadProgress < 0 {
                            // Error state
                            self.serverStatus = .error("Model loading failed")
                            self.statusMessage = "Failed to load AI model. Check server logs."
                            self.modelDownloadProgress = 0.0
                        } else if downloadProgress > 0 && downloadProgress < 0.9 {
                            // Actually downloading
                            self.serverStatus = .downloadingModel(progress: downloadProgress)
                            self.statusMessage = "Downloading Gemma 3n model (~8GB): \(Int(downloadProgress * 100))%"
                            self.modelDownloadProgress = downloadProgress
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
    
    private func checkPortAvailability() async -> Bool {
        // Check if port is already in use
        do {
            let url = URL(string: "http://127.0.0.1:\(serverPort)/api/health")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 1.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                logger.info("Port \(self.serverPort) already has a server running")
                return false // Port is in use
            }
        } catch {
            // Port is free (connection failed)
            return true
        }
        return true
    }
    
    private func performServerLaunch() async throws {
        // Check if port is available first
        if await !checkPortAvailability() {
            // Another server is already running on this port
            if await checkHealth() {
                // It's a healthy Gemi server
                serverStatus = .ready
                statusMessage = "Connected to existing server"
                logger.info("Connected to existing Gemi server on port \(self.serverPort)")
                return
            } else {
                // Something else is using the port
                let error = "Port \(self.serverPort) is already in use by another application"
                serverStatus = .error(error)
                statusMessage = error
                logger.error("Port conflict: \(error)")
                throw ServerError.connectionFailed("Port \(self.serverPort) unavailable")
            }
        }
        
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
                            // SIGKILL - usually code signing or permission issue
                            self.serverStatus = .error("Server terminated - permission issue")
                            self.statusMessage = "Server permission error. Attempting automatic recovery..."
                            
                            // Attempt to fix permissions and restart
                            Task {
                                self.logger.info("Attempting to fix server permissions...")
                                await self.fixServerPermissions()
                                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                                
                                // Only retry once to avoid infinite loop
                                if !self.hasRetriedAfter137 {
                                    self.hasRetriedAfter137 = true
                                    self.logger.info("Retrying server launch after permission fix...")
                                    try? await self.startServer()
                                }
                            }
                        } else if exitCode == 1 {
                            self.serverStatus = .error("Server startup failed")
                            self.statusMessage = "Server failed to start. Check if port 11435 is already in use."
                        } else {
                            self.serverStatus = .error("Server exited with code \(exitCode)")
                            self.statusMessage = "Server process failed. Please try restarting Gemi."
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
    
    private func cleanupZombieProcesses() {
        // Kill any lingering GemiServer or python processes
        let zombiePatterns = ["GemiServer", "inference_server.py", "python.*inference_server"]
        
        for pattern in zombiePatterns {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            task.arguments = ["-f", pattern]
            
            do {
                try task.run()
                task.waitUntilExit()
                if task.terminationStatus == 0 {
                    logger.info("Cleaned up zombie process matching: \(pattern)")
                }
            } catch {
                // pkill might not find anything, which is fine
                logger.debug("No zombie processes found for pattern: \(pattern)")
            }
        }
    }
    
    private func fixServerPermissions() async {
        let serverURL = locateServerBundle()
        let executablePath = serverURL.appendingPathComponent("Contents/MacOS/GemiServer")
        
        do {
            // Make executable
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/chmod")
            process.arguments = ["+x", executablePath.path]
            try process.run()
            process.waitUntilExit()
            
            // Re-sign with ad-hoc signature
            let codesignProcess = Process()
            codesignProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            codesignProcess.arguments = ["--force", "--deep", "--sign", "-", serverURL.path]
            try codesignProcess.run()
            codesignProcess.waitUntilExit()
            
            logger.info("Fixed server permissions and re-signed bundle")
        } catch {
            logger.error("Failed to fix server permissions: \(error)")
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