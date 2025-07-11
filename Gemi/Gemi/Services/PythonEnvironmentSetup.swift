import Foundation
import AppKit

/// Manages Python environment setup for Gemma 3n using UV
@MainActor
class PythonEnvironmentSetup: ObservableObject {
    @Published var currentStep: SetupStep = .checkingEnvironment
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = "Initializing..."
    @Published var isComplete: Bool = false
    @Published var error: SetupError?
    
    enum SetupStep: String, CaseIterable {
        case checkingEnvironment = "Checking Environment"
        case installingUV = "Installing UV"
        case installingDependencies = "Installing Dependencies"
        case launchingServer = "Launching Server"
        case downloadingModel = "Downloading Model"
        case complete = "Complete"
        
        var description: String {
            switch self {
            case .checkingEnvironment:
                return "Checking for UV installation..."
            case .installingUV:
                return "Installing UV package manager..."
            case .installingDependencies:
                return "Installing PyTorch, Transformers, and dependencies..."
            case .launchingServer:
                return "Starting the AI server..."
            case .downloadingModel:
                return "Downloading Gemma 3n model from HuggingFace..."
            case .complete:
                return "Setup complete! Gemma 3n is ready."
            }
        }
        
        var icon: String {
            switch self {
            case .checkingEnvironment: return "magnifyingglass"
            case .installingUV: return "bolt.fill"
            case .installingDependencies: return "puzzlepiece.extension"
            case .launchingServer: return "play.circle"
            case .downloadingModel: return "icloud.and.arrow.down"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }
    
    enum SetupError: LocalizedError {
        case uvInstallFailed
        case dependencyInstallFailed
        case serverNotFound
        case launchFailed(String)
        case modelAuthRequired
        
        var errorDescription: String? {
            switch self {
            case .uvInstallFailed:
                return "UV package manager not found"
            case .dependencyInstallFailed:
                return "Failed to install required packages"
            case .serverNotFound:
                return "Server files not found in project"
            case .launchFailed(let reason):
                return "Failed to launch server: \(reason)"
            case .modelAuthRequired:
                return "HuggingFace authentication required for Gemma 3n model"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .uvInstallFailed:
                return "UV is required for Gemi. Click 'Manual Setup' to install it via Terminal"
            case .dependencyInstallFailed:
                return "Check internet connection and try: uv sync --refresh"
            case .serverNotFound:
                return "Ensure python-inference-server directory exists in project"
            case .launchFailed:
                return "Check Terminal output for detailed error messages"
            case .modelAuthRequired:
                return "You need to authenticate with HuggingFace to access the Gemma 3n model. Click 'Manual Setup' for instructions."
            }
        }
    }
    
    private let projectPath = NSHomeDirectory() + "/Documents/project-Gemi"
    private let serverPath = NSHomeDirectory() + "/Documents/project-Gemi/python-inference-server"
    
    func startSetup() {
        Task {
            await performSetup()
        }
    }
    
    private func performSetup() async {
        do {
            // Step 1: Check if UV is installed
            try await checkEnvironment()
            
            // Step 2: Install UV if needed
            if !isUVInstalled() {
                try await installUV()
                
                // Verify UV was installed successfully before proceeding
                statusMessage = "Verifying UV installation..."
                var uvReady = false
                for _ in 1...10 {
                    if isUVInstalled() {
                        uvReady = true
                        break
                    }
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
                
                guard uvReady else {
                    throw SetupError.uvInstallFailed
                }
            } else {
                statusMessage = "UV already installed!"
                progress = 0.3
            }
            
            // Step 3: Install dependencies with UV
            try await installDependencies()
            
            // Step 4: Launch server
            try await launchServer()
            
            // Step 5: Model setup
            currentStep = .downloadingModel
            statusMessage = "Setting up Gemma 3n model..."
            progress = 0.9
            
            // Wait for server to be ready
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            // Check server health to see if model is loaded
            let serverStatus = await PythonServerManager.shared.getServerStatus()
            
            switch serverStatus {
            case .notRunning:
                throw SetupError.launchFailed("Server failed to start")
            case .loading:
                statusMessage = "Model downloading... This may take 10-30 minutes"
            case .ready:
                statusMessage = "Model ready!"
            }
            
            // Complete
            currentStep = .complete
            statusMessage = "Setup complete!"
            progress = 1.0
            isComplete = true
            
        } catch let setupError as SetupError {
            self.error = setupError
            statusMessage = setupError.localizedDescription
        } catch {
            self.error = .launchFailed(error.localizedDescription)
            statusMessage = error.localizedDescription
        }
    }
    
    private func checkEnvironment() async throws {
        currentStep = .checkingEnvironment
        statusMessage = "Checking for UV installation..."
        progress = 0.1
        
        // Check if server directory exists first
        guard FileManager.default.fileExists(atPath: serverPath) else {
            throw SetupError.serverNotFound
        }
        
        // Check for key required files more gracefully
        let keyFile = serverPath + "/pyproject.toml"
        guard FileManager.default.fileExists(atPath: keyFile) else {
            // Directory exists but missing key files
            statusMessage = "Server directory found but missing configuration files"
            throw SetupError.serverNotFound
        }
        
        progress = 0.2
    }
    
    private func isUVInstalled() -> Bool {
        // Check common UV installation paths
        let uvPaths = getUVPaths()
        
        for path in uvPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        return false
    }
    
    private func getUVPaths() -> [String] {
        return [
            NSHomeDirectory() + "/.local/bin/uv", // UV installer default
            NSHomeDirectory() + "/.cargo/bin/uv",  // Rust cargo install
            "/usr/local/bin/uv",                  // Intel Mac homebrew
            "/opt/homebrew/bin/uv",               // Apple Silicon homebrew
            "/usr/bin/uv"                          // System-wide install
        ]
    }
    
    private func installUV() async throws {
        currentStep = .installingUV
        statusMessage = "Installing UV package manager..."
        progress = 0.25
        
        // For sandboxed apps, we need to handle UV installation differently
        // First check if UV is already installed outside the sandbox
        if isUVInstalled() {
            statusMessage = "UV already installed!"
            progress = 0.3
            return
        }
        
        // If not installed, we need to guide the user to install it manually
        // because sandboxed apps cannot install executables
        statusMessage = "UV not found. Opening manual setup..."
        
        // Create a more informative error that will trigger manual setup
        throw SetupError.uvInstallFailed
    }
    
    private func installDependencies() async throws {
        currentStep = .installingDependencies
        statusMessage = "Installing PyTorch and dependencies..."
        progress = 0.4
        
        // Find UV path with better error handling
        statusMessage = "Locating UV package manager..."
        
        // Try multiple times in case UV is still being written to disk
        var uvPath: String? = nil
        for attempt in 1...5 {
            if let foundPath = findUVPath() {
                uvPath = foundPath
                break
            }
            statusMessage = "Looking for UV... (attempt \(attempt)/5)"
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        guard let uvPath = uvPath else {
            // Provide more diagnostic information
            let searchedPaths = getUVPaths().joined(separator: "\n  ")
            print("UV not found in any of these locations:\n  \(searchedPaths)")
            statusMessage = "UV not found. Please install manually."
            throw SetupError.uvInstallFailed
        }
        
        // Verify UV file exists and is executable
        guard FileManager.default.fileExists(atPath: uvPath) else {
            print("UV path found but file doesn't exist: \(uvPath)")
            throw SetupError.uvInstallFailed
        }
        
        // Double-check it's executable
        guard FileManager.default.isExecutableFile(atPath: uvPath) else {
            print("UV exists but is not executable: \(uvPath)")
            // Try to make it executable
            let chmodProcess = Process()
            chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodProcess.arguments = ["+x", uvPath]
            try? chmodProcess.run()
            chmodProcess.waitUntilExit()
            throw SetupError.uvInstallFailed
        }
        
        statusMessage = "Found UV at: \(uvPath)"
        
        // Change to server directory and sync
        let syncProcess = Process()
        syncProcess.executableURL = URL(fileURLWithPath: uvPath)
        syncProcess.arguments = ["sync"]
        syncProcess.currentDirectoryURL = URL(fileURLWithPath: serverPath)
        
        statusMessage = "Installing all dependencies (this is fast with UV!)..."
        
        do {
            try syncProcess.run()
            syncProcess.waitUntilExit()
        } catch let processError as NSError {
            // More detailed error information
            print("Failed to run UV sync at path: \(uvPath)")
            print("Error: \(processError.localizedDescription)")
            print("Error code: \(processError.code)")
            
            // Check if it's a "file not found" error
            if processError.code == 4 { // NSFileNoSuchFileError
                statusMessage = "UV binary not found at expected location"
                throw SetupError.uvInstallFailed
            } else {
                throw SetupError.dependencyInstallFailed
            }
        }
        
        if syncProcess.terminationStatus != 0 {
            throw SetupError.dependencyInstallFailed
        }
        
        progress = 0.7
        statusMessage = "Dependencies installed successfully!"
    }
    
    private func launchServer() async throws {
        currentStep = .launchingServer
        statusMessage = "Starting Gemma 3n server..."
        progress = 0.8
        
        // Launch server in Terminal
        let script = """
        tell application "Terminal"
            activate
            set newWindow to do script "cd '\(serverPath)' && ./launch_server.sh"
            set custom title of first window to "Gemi AI Server"
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                throw SetupError.launchFailed(error.description)
            }
        }
        
        // Wait for server to start
        statusMessage = "Waiting for server to initialize..."
        
        var attempts = 0
        while attempts < 30 {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            if await checkServerHealth() {
                progress = 0.9
                return
            }
            
            attempts += 1
            progress = 0.8 + (0.1 * Double(attempts) / 30.0)
        }
        
        throw SetupError.launchFailed("Server startup timeout")
    }
    
    private func checkServerHealth() async -> Bool {
        do {
            let healthURL = URL(string: "http://127.0.0.1:11435/api/health")!
            let (_, response) = try await URLSession.shared.data(from: healthURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            // Server not ready yet
        }
        
        return false
    }
    
    private func findUVPath() -> String? {
        let uvPaths = getUVPaths()
        
        for path in uvPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
}