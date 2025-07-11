import Foundation
import AppKit

/// Manages the Python inference server lifecycle
actor PythonServerManager {
    static let shared = PythonServerManager()
    
    private var serverProcess: Process?
    private var isServerRunning = false
    private let serverPath = "\(NSHomeDirectory())/Documents/project-Gemi/python-inference-server"
    
    private init() {}
    
    /// Check if the Python server is already running
    func isServerRunning() async -> Bool {
        do {
            let healthURL = URL(string: await AIConfiguration.shared.apiHealthURL)!
            let (_, response) = try await URLSession.shared.data(from: healthURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            // Server not reachable
        }
        
        return false
    }
    
    /// Launch the Python server
    func launchServer() async throws {
        // Check if already running
        if await isServerRunning() {
            isServerRunning = true
            return
        }
        
        // Check if server directory exists
        guard FileManager.default.fileExists(atPath: serverPath) else {
            throw PythonServerError.serverNotFound
        }
        
        // Launch the server using the launch script
        let launchScriptPath = "\(serverPath)/launch_server.sh"
        guard FileManager.default.fileExists(atPath: launchScriptPath) else {
            throw PythonServerError.launchScriptNotFound
        }
        
        // Open in Terminal for visibility
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
                throw PythonServerError.failedToLaunch(error.description)
            }
        }
        
        // Wait for server to be ready (max 60 seconds for model download)
        var attempts = 0
        while attempts < 60 {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            if await isServerRunning() {
                isServerRunning = true
                return
            }
            
            attempts += 1
        }
        
        throw PythonServerError.startupTimeout
    }
    
    /// Open server documentation
    func openDocumentation() {
        let readmePath = "\(serverPath)/README.md"
        if FileManager.default.fileExists(atPath: readmePath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: readmePath))
        }
    }
    
    /// Get server status details
    func getServerStatus() async -> ServerStatus {
        do {
            let healthURL = URL(string: await AIConfiguration.shared.apiHealthURL)!
            let (data, response) = try await URLSession.shared.data(from: healthURL)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let healthData = try? JSONDecoder().decode(ServerHealthResponse.self, from: data) {
                
                if healthData.model_loaded {
                    return .ready
                } else {
                    let progress = Int(healthData.download_progress * 100)
                    return .loading(progress: progress)
                }
            }
        } catch {
            // Server not running
        }
        
        return .notRunning
    }
    
    enum ServerStatus {
        case notRunning
        case loading(progress: Int)
        case ready
        
        var description: String {
            switch self {
            case .notRunning:
                return "Server not running"
            case .loading(let progress):
                return "Loading model: \(progress)%"
            case .ready:
                return "Ready"
            }
        }
        
        var isOperational: Bool {
            switch self {
            case .ready:
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - Errors

enum PythonServerError: LocalizedError {
    case serverNotFound
    case launchScriptNotFound
    case failedToLaunch(String)
    case startupTimeout
    
    var errorDescription: String? {
        switch self {
        case .serverNotFound:
            return "Python server directory not found"
        case .launchScriptNotFound:
            return "launch_server.sh not found"
        case .failedToLaunch(let reason):
            return "Failed to launch server: \(reason)"
        case .startupTimeout:
            return "Server startup timed out"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .serverNotFound, .launchScriptNotFound:
            return "Ensure python-inference-server directory exists in project root"
        case .failedToLaunch:
            return "Try launching manually: cd python-inference-server && ./launch_server.sh"
        case .startupTimeout:
            return "Model download may be in progress. Check Terminal for status."
        }
    }
}

// Health response model
private struct ServerHealthResponse: Codable {
    let status: String
    let model_loaded: Bool
    let device: String
    let mps_available: Bool
    let download_progress: Double
}