import Foundation
import AppKit

/// Manages the Ollama process lifecycle
actor OllamaProcessManager {
    static let shared = OllamaProcessManager()
    
    private var ollamaProcess: Process?
    private var isOllamaRunning = false
    private var startupAttempts = 0
    private let maxStartupAttempts = 3
    
    /// Paths to check for Ollama installation
    private let ollamaPaths = [
        "/usr/local/bin/ollama",
        "/opt/homebrew/bin/ollama",
        "/usr/bin/ollama",
        // Check in Applications folder
        "/Applications/Ollama.app/Contents/MacOS/ollama",
        "/Applications/Ollama.app/Contents/Resources/ollama"
    ]
    
    private init() {}
    
    /// Check if Ollama is installed on the system
    func isOllamaInstalled() -> Bool {
        // Check standard paths
        for path in ollamaPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Check if ollama is in PATH
        let checkProcess = Process()
        checkProcess.launchPath = "/usr/bin/which"
        checkProcess.arguments = ["ollama"]
        
        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        checkProcess.standardError = Pipe()
        
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if !data.isEmpty {
                return true
            }
        } catch {
            print("Error checking for ollama: \(error)")
        }
        
        return false
    }
    
    /// Get the path to Ollama executable
    private func getOllamaPath() -> String? {
        // Check predefined paths first
        for path in ollamaPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try to find it using which
        let checkProcess = Process()
        checkProcess.launchPath = "/usr/bin/which"
        checkProcess.arguments = ["ollama"]
        
        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        checkProcess.standardError = Pipe()
        
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {
            print("Error finding ollama path: \(error)")
        }
        
        return nil
    }
    
    /// Check if Ollama server is already running
    func isOllamaServerRunning() async -> Bool {
        do {
            let url = URL(string: "http://localhost:11434/api/tags")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            // Server not reachable
        }
        
        return false
    }
    
    /// Start Ollama server if not running
    func ensureOllamaRunning() async throws {
        // Check if already running
        if await isOllamaServerRunning() {
            isOllamaRunning = true
            return
        }
        
        // Check if Ollama is installed
        guard isOllamaInstalled() else {
            throw OllamaProcessError.notInstalled
        }
        
        // Get Ollama path
        guard let ollamaPath = getOllamaPath() else {
            throw OllamaProcessError.pathNotFound
        }
        
        // Start Ollama
        try await startOllamaServer(at: ollamaPath)
    }
    
    /// Start the Ollama server process
    private func startOllamaServer(at path: String) async throws {
        if startupAttempts >= maxStartupAttempts {
            throw OllamaProcessError.maxAttemptsReached
        }
        
        startupAttempts += 1
        
        // First, check if another Ollama instance is already running
        if await isPortInUse(11434) {
            // Check if it's a valid Ollama server
            if await isOllamaServerRunning() {
                isOllamaRunning = true
                startupAttempts = 0
                print("Ollama server already running on port 11434")
                return
            } else {
                // Port is in use but not by Ollama
                throw OllamaProcessError.portInUse
            }
        }
        
        // Kill any existing Ollama processes that might be hanging
        await killExistingOllamaProcesses()
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["serve"]
        
        // Set environment variables
        var environment = ProcessInfo.processInfo.environment
        environment["OLLAMA_DEBUG"] = "1" // Enable debug logging
        environment["OLLAMA_HOST"] = "127.0.0.1:11434" // Explicitly set host
        environment["HOME"] = NSHomeDirectory() // Ensure HOME is set
        process.environment = environment
        
        // Set current directory to user's home directory
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        
        // Create pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Create thread-safe storage for output
        let outputStorage = ProcessOutputStorage()
        
        // Set up handlers to capture output
        outputPipe.fileHandleForReading.readabilityHandler = { [outputStorage] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                Task {
                    await outputStorage.appendStandardOutput(output)
                    print("[Ollama stdout]: \(output)")
                }
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [outputStorage] handle in
            let data = handle.availableData
            if let error = String(data: data, encoding: .utf8), !error.isEmpty {
                Task {
                    await outputStorage.appendErrorOutput(error)
                    print("[Ollama stderr]: \(error)")
                }
            }
        }
        
        // Set up termination handler
        process.terminationHandler = { [weak self] process in
            Task {
                await self?.handleProcessTermination(process)
            }
        }
        
        do {
            try process.run()
            ollamaProcess = process
            
            // Give the process a moment to start
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Check if process is still running
            if !process.isRunning {
                let exitStatus = process.terminationStatus
                print("[Ollama] Process exited immediately with status: \(exitStatus)")
                
                // Wait a bit to collect any error output
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                let errorOutput = await outputStorage.getErrorOutput()
                let standardOutput = await outputStorage.getStandardOutput()
                
                if !errorOutput.isEmpty {
                    print("[Ollama] Error output: \(errorOutput)")
                }
                if !standardOutput.isEmpty {
                    print("[Ollama] Standard output: \(standardOutput)")
                }
                
                // If serve command failed, check if Ollama is already running (e.g., from app)
                if await isOllamaServerRunning() {
                    isOllamaRunning = true
                    startupAttempts = 0
                    print("[Ollama] Server already running (possibly from Ollama.app)")
                    
                    // Check if model needs to be pulled
                    try await ensureModelAvailable()
                    return
                }
                
                // Try alternative approach: check if Ollama app is installed
                if let ollamaAppPath = findOllamaApp() {
                    print("[Ollama] Found Ollama.app, attempting to launch it instead")
                    try await launchOllamaApp(at: ollamaAppPath)
                    return
                } else {
                    let capturedErrorOutput = await outputStorage.getErrorOutput()
                    let errorDetails = capturedErrorOutput.isEmpty ? "No error output captured" : capturedErrorOutput
                    throw OllamaProcessError.failedToStart("Process exited with status \(exitStatus). Error: \(errorDetails)")
                }
            }
            
            // Wait for server to be ready (max 30 seconds)
            var attempts = 0
            while attempts < 30 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                if await isOllamaServerRunning() {
                    isOllamaRunning = true
                    startupAttempts = 0 // Reset on success
                    print("[Ollama] Server is now running and responsive")
                    
                    // Check if model needs to be pulled
                    try await ensureModelAvailable()
                    
                    return
                }
                
                // Check if process is still running
                if !process.isRunning {
                    print("[Ollama] Process terminated during startup")
                    throw OllamaProcessError.failedToStart("Process terminated unexpectedly")
                }
                
                attempts += 1
            }
            
            throw OllamaProcessError.startupTimeout
            
        } catch {
            ollamaProcess = nil
            print("[Ollama] Failed to start: \(error)")
            throw OllamaProcessError.failedToStart(error.localizedDescription)
        }
    }
    
    /// Ensure the gemma3n model is available
    private func ensureModelAvailable() async throws {
        let ollamaService = OllamaService.shared
        
        do {
            let hasModel = try await ollamaService.checkHealth()
            if !hasModel {
                // Pull the model
                NotificationCenter.default.post(
                    name: .ollamaModelDownloading,
                    object: nil,
                    userInfo: ["status": "Downloading Gemma 3n model..."]
                )
                
                try await ollamaService.pullModel("gemma3n:latest") { progress, status in
                    NotificationCenter.default.post(
                        name: .ollamaModelDownloading,
                        object: nil,
                        userInfo: [
                            "progress": progress,
                            "status": status
                        ]
                    )
                }
                
                // Create companion model
                try await CompanionModelService.shared.setupCompanionModel()
                
                NotificationCenter.default.post(
                    name: .ollamaModelReady,
                    object: nil
                )
            }
        } catch {
            print("Error ensuring model availability: \(error)")
            throw error
        }
    }
    
    /// Handle process termination
    private func handleProcessTermination(_ process: Process) async {
        isOllamaRunning = false
        ollamaProcess = nil
        
        if process.terminationStatus != 0 {
            print("Ollama process terminated with status: \(process.terminationStatus)")
            print("Termination reason: \(process.terminationReason.rawValue)")
            
            // Try to restart if it crashed
            if startupAttempts < maxStartupAttempts {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
                try? await ensureOllamaRunning()
            } else {
                // Send notification about failure
                NotificationCenter.default.post(
                    name: .ollamaStatusChanged,
                    object: nil,
                    userInfo: ["error": "Ollama failed to start after \(maxStartupAttempts) attempts"]
                )
            }
        }
    }
    
    /// Check if a port is in use
    private func isPortInUse(_ port: Int) async -> Bool {
        let checkProcess = Process()
        checkProcess.launchPath = "/usr/bin/lsof"
        checkProcess.arguments = ["-i", ":\(port)"]
        
        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        checkProcess.standardError = Pipe()
        
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return !data.isEmpty
        } catch {
            print("Error checking port: \(error)")
            return false
        }
    }
    
    /// Find Ollama.app if installed
    private func findOllamaApp() -> String? {
        let appPaths = [
            "/Applications/Ollama.app",
            "/System/Applications/Ollama.app",
            "\(NSHomeDirectory())/Applications/Ollama.app"
        ]
        
        for path in appPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
    /// Launch Ollama.app instead of running ollama serve
    private func launchOllamaApp(at path: String) async throws {
        let workspace = NSWorkspace.shared
        let appURL = URL(fileURLWithPath: path)
        
        // Launch the app
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        
        do {
            _ = try await workspace.openApplication(at: appURL, configuration: configuration)
            
            // Wait for server to be ready
            var attempts = 0
            while attempts < 30 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                if await isOllamaServerRunning() {
                    isOllamaRunning = true
                    startupAttempts = 0
                    print("[Ollama] App launched successfully, server is running")
                    
                    // Check if model needs to be pulled
                    try await ensureModelAvailable()
                    
                    return
                }
                
                attempts += 1
            }
            
            throw OllamaProcessError.startupTimeout
            
        } catch {
            print("[Ollama] Failed to launch app: \(error)")
            throw OllamaProcessError.failedToStart("Could not launch Ollama.app: \(error.localizedDescription)")
        }
    }
    
    /// Kill any existing Ollama processes
    private func killExistingOllamaProcesses() async {
        // First try to kill any 'ollama serve' processes
        let killServeProcess = Process()
        killServeProcess.launchPath = "/usr/bin/pkill"
        killServeProcess.arguments = ["-f", "ollama serve"]
        
        do {
            try killServeProcess.run()
            killServeProcess.waitUntilExit()
        } catch {
            // It's okay if pkill fails (no processes to kill)
        }
        
        // Also kill any general ollama processes
        let killOllamaProcess = Process()
        killOllamaProcess.launchPath = "/usr/bin/pkill"
        killOllamaProcess.arguments = ["ollama"]
        
        do {
            try killOllamaProcess.run()
            killOllamaProcess.waitUntilExit()
        } catch {
            // It's okay if pkill fails (no processes to kill)
        }
        
        // Wait a bit for processes to clean up
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        print("Cleaned up any existing Ollama processes")
    }
    
    /// Stop Ollama server
    func stopOllama() async {
        if let process = ollamaProcess, process.isRunning {
            process.terminate()
            
            // Wait for graceful shutdown
            var attempts = 0
            while process.isRunning && attempts < 10 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                attempts += 1
            }
            
            // Force kill if still running
            if process.isRunning {
                process.interrupt()
            }
        }
        
        ollamaProcess = nil
        isOllamaRunning = false
    }
    
    /// Open Ollama download page
    func openOllamaDownloadPage() {
        if let url = URL(string: "https://ollama.ai") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Errors

enum OllamaProcessError: LocalizedError {
    case notInstalled
    case pathNotFound
    case failedToStart(String)
    case startupTimeout
    case maxAttemptsReached
    case portInUse
    case serverNotResponding
    
    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Ollama is not installed. Please download it from ollama.ai"
        case .pathNotFound:
            return "Could not find Ollama executable"
        case .failedToStart(let reason):
            return "Failed to start Ollama: \(reason)"
        case .startupTimeout:
            return "Ollama server startup timed out"
        case .maxAttemptsReached:
            return "Failed to start Ollama after multiple attempts"
        case .portInUse:
            return "Port 11434 is already in use by another process"
        case .serverNotResponding:
            return "Ollama server is not responding"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let ollamaStatusChanged = Notification.Name("ollamaStatusChanged")
    static let ollamaModelDownloading = Notification.Name("ollamaModelDownloading")
    static let ollamaModelReady = Notification.Name("ollamaModelReady")
}

// MARK: - Thread-Safe Output Storage

private actor ProcessOutputStorage {
    private var standardOutput = ""
    private var errorOutput = ""
    
    func appendStandardOutput(_ text: String) {
        standardOutput += text
    }
    
    func appendErrorOutput(_ text: String) {
        errorOutput += text
    }
    
    func getStandardOutput() -> String {
        return standardOutput
    }
    
    func getErrorOutput() -> String {
        return errorOutput
    }
}