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
        // Try multiple server launch approaches
        let launchOptions = findServerLaunchOptions()
        
        guard !launchOptions.isEmpty else {
            let error = "No server launch method found. Please reinstall Gemi."
            serverStatus = .error(error)
            statusMessage = error
            logger.error("No server launch options available")
            throw ServerError.serverNotFound
        }
        
        var lastError: Error?
        
        // Try each launch option in order
        for (method, executableURL) in launchOptions {
            logger.info("Attempting to launch server using \(method): \(executableURL.path)")
            
            do {
                try await launchServerWithExecutable(executableURL: executableURL)
                logger.info("Successfully launched server using \(method)")
                return
            } catch {
                logger.error("Failed to launch using \(method): \(error.localizedDescription)")
                lastError = error
                // Continue to next method
            }
        }
        
        // All methods failed
        let error = "Failed to launch server with any method"
        serverStatus = .error(error)
        statusMessage = error
        throw lastError ?? ServerError.serverNotFound
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
        
        // Special handling for UV-based launches
        if executableURL.lastPathComponent == "launch_server.sh" {
            // Launch shell script
            process.arguments = []
        } else if executableURL.lastPathComponent == "uv" {
            // Direct UV execution
            let serverDir = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Documents/project-Gemi/python-inference-server")
            process.currentDirectoryURL = serverDir
            process.arguments = ["run", "python", "inference_server.py"]
        }
        
        // Rest of the original launch code continues...
        
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
                    }
                }
            }
        }
    }
    
    private func findServerLaunchOptions() -> [(method: String, executable: URL)] {
        var options: [(method: String, executable: URL)] = []
        
        // First, try to ensure server is bundled (for development builds)
        ensureServerBundled()
        
        // Option 1: Bundled GemiServer.app
        let bundledLocations = [
            // Inside Gemi.app bundle
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/GemiServer.app/Contents/MacOS/GemiServer"),
            // Same directory as Gemi.app
            Bundle.main.bundleURL.deletingLastPathComponent()
                .appendingPathComponent("GemiServer.app/Contents/MacOS/GemiServer"),
            // Development location
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Documents/project-Gemi/python-inference-server/dist/GemiServer.app/Contents/MacOS/GemiServer")
        ]
        
        for location in bundledLocations {
            if FileManager.default.fileExists(atPath: location.path) {
                options.append((method: "PyInstaller Bundle", executable: location))
                break
            }
        }
        
        // Option 2: UV-based launch script
        let launchScriptLocations = [
            // Development location
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Documents/project-Gemi/python-inference-server/launch_server.sh"),
            // Bundled location
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/launch_server.sh")
        ]
        
        for location in launchScriptLocations {
            if FileManager.default.fileExists(atPath: location.path) {
                options.append((method: "UV Launch Script", executable: location))
                break
            }
        }
        
        // Option 3: Direct UV command (if UV is available)
        if let uvPath = findUVExecutable() {
            // Use UV to run the inference server directly
            options.append((method: "UV Direct", executable: uvPath))
        }
        
        // Log all options for debugging
        logger.info("Found \(options.count) server launch options:")
        for (index, option) in options.enumerated() {
            logger.info("  \(index + 1). \(option.method): \(option.executable.path)")
        }
        
        return options
    }
    
    private func findUVExecutable() -> URL? {
        // Check common UV installation locations
        let uvPaths = [
            "/Users/\(NSUserName())/.local/bin/uv",
            "/usr/local/bin/uv",
            "/opt/homebrew/bin/uv"
        ]
        
        for path in uvPaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        
        return nil
    }
    
    private func locateServerBundle() -> URL {
        // First, try to ensure server is bundled (for development builds)
        ensureServerBundled()
        
        // Check multiple locations in priority order
        let locations = [
            // 1. Inside Gemi.app bundle (primary location)
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/GemiServer.app"),
            
            // 2. Same directory as Gemi.app (for DMG distribution)
            Bundle.main.bundleURL.deletingLastPathComponent()
                .appendingPathComponent("GemiServer.app"),
            
            // 3. In /Applications (standard installation)
            URL(fileURLWithPath: "/Applications/GemiServer.app"),
            
            // 4. In ~/Applications (user installation)
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications/GemiServer.app"),
            
            // 5. Development location (for testing)
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Documents/project-Gemi/python-inference-server/dist/GemiServer.app")
        ]
        
        // Log all locations being checked for debugging
        logger.info("Searching for GemiServer.app in the following locations:")
        for (index, location) in locations.enumerated() {
            let exists = FileManager.default.fileExists(atPath: location.path)
            logger.info("  \(index + 1). \(location.path) - \(exists ? "FOUND" : "not found")")
        }
        
        // Find first existing location
        for location in locations {
            if FileManager.default.fileExists(atPath: location.path) {
                logger.info("Using GemiServer at: \(location.path)")
                return location
            }
        }
        
        // Default to /Applications
        logger.error("GemiServer.app not found in any expected location")
        return URL(fileURLWithPath: "/Applications/GemiServer.app")
    }
    
    /// Attempts to bundle GemiServer.app if running in development mode
    private func ensureServerBundled() {
        #if DEBUG
        // Only try to auto-bundle in debug builds
        let resourcesPath = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
        let serverDestPath = resourcesPath.appendingPathComponent("GemiServer.app")
        
        // Check if already bundled
        if FileManager.default.fileExists(atPath: serverDestPath.path) {
            return
        }
        
        // Look for server in development location
        let devServerPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/project-Gemi/python-inference-server/dist/GemiServer.app")
        
        if FileManager.default.fileExists(atPath: devServerPath.path) {
            logger.info("Development mode: Attempting to bundle GemiServer.app")
            
            do {
                // Create Resources directory if needed
                try FileManager.default.createDirectory(at: resourcesPath, withIntermediateDirectories: true)
                
                // Copy server to bundle
                try FileManager.default.copyItem(at: devServerPath, to: serverDestPath)
                logger.info("Successfully bundled GemiServer.app for development")
            } catch {
                logger.error("Failed to bundle GemiServer.app: \(error)")
            }
        }
        #endif
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