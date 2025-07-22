import Foundation
import AppKit

/// Handles Ollama installation and setup for Gemi
@MainActor
final class OllamaInstaller: NSObject, ObservableObject {
    static let shared = OllamaInstaller()
    
    // MARK: - Published Properties
    
    @Published var installationStatus: InstallationStatus = .notChecked
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""
    
    // MARK: - Types
    
    enum InstallationStatus: Equatable {
        case notChecked
        case checking
        case installed
        case notInstalled
        case downloading(progress: Double)
        case installing
        case error(String)
    }
    
    // MARK: - Private Properties
    
    private let ollamaDownloadURL = "https://ollama.com/download/Ollama-darwin.zip"
    private let ollamaAppPath = "/Applications/Ollama.app"
    private let ollamaCliPath = "/usr/local/bin/ollama"
    private var downloadTask: URLSessionDownloadTask?
    
    // MARK: - Initialization
    
    override private init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Check if Ollama is installed
    func checkInstallation() async -> Bool {
        installationStatus = .checking
        
        // Check for Ollama CLI
        let fileManager = FileManager.default
        let cliExists = fileManager.fileExists(atPath: ollamaCliPath)
        let appExists = fileManager.fileExists(atPath: ollamaAppPath)
        
        // Also check if ollama command is available via which
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["ollama"]
        
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        whichProcess.standardError = FileHandle.nullDevice
        
        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            
            let isAvailable = whichProcess.terminationStatus == 0 || cliExists || appExists
            installationStatus = isAvailable ? .installed : .notInstalled
            return isAvailable
        } catch {
            installationStatus = .notInstalled
            return false
        }
    }
    
    /// Install Ollama automatically
    func installOllama() async throws {
        guard installationStatus == .notInstalled else { return }
        
        installationStatus = .downloading(progress: 0.0)
        downloadStatus = "Downloading Ollama..."
        
        // Download Ollama
        let tempURL = try await downloadOllamaApp()
        
        installationStatus = .installing
        downloadStatus = "Installing Ollama..."
        
        // Extract and install
        try await installDownloadedApp(from: tempURL)
        
        // Verify installation
        let isInstalled = await checkInstallation()
        if !isInstalled {
            throw OllamaInstallerError.installationFailed
        }
        
        downloadStatus = "Installation complete!"
    }
    
    /// Start Ollama server
    func startOllamaServer() async throws {
        // First, try to launch Ollama.app if it exists
        if FileManager.default.fileExists(atPath: ollamaAppPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: ollamaAppPath))
            
            // Wait for server to start
            for _ in 0..<30 {
                if await OllamaChatService.shared.health().healthy {
                    return
                }
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        // If app launch didn't work, try CLI
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ollamaCliPath)
        process.arguments = ["serve"]
        
        // Run in background
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        
        // Wait for server to start
        for _ in 0..<30 {
            if await OllamaChatService.shared.health().healthy {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        throw OllamaInstallerError.serverStartFailed
    }
    
    /// One-click setup: Install Ollama, start server, and pull model
    func performCompleteSetup() async throws {
        // Step 1: Check installation
        let isInstalled = await checkInstallation()
        
        // Step 2: Install if needed
        if !isInstalled {
            try await installOllama()
        }
        
        // Step 3: Start server
        try await startOllamaServer()
        
        // Step 4: Pull model (handled by OllamaChatService)
        downloadStatus = "Downloading AI model (7.5GB)..."
        try await OllamaChatService.shared.loadModel()
        
        downloadStatus = "Setup complete!"
    }
    
    // MARK: - Private Methods
    
    private func downloadOllamaApp() async throws -> URL {
        guard let url = URL(string: ollamaDownloadURL) else {
            throw OllamaInstallerError.invalidDownloadURL
        }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        
        return try await withCheckedThrowingContinuation { continuation in
            downloadTask = session.downloadTask(with: url) { location, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let location = location else {
                    continuation.resume(throwing: OllamaInstallerError.downloadFailed)
                    return
                }
                
                // Move to temporary location
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent("Ollama-darwin.zip")
                
                do {
                    if FileManager.default.fileExists(atPath: tempFile.path) {
                        try FileManager.default.removeItem(at: tempFile)
                    }
                    try FileManager.default.moveItem(at: location, to: tempFile)
                    continuation.resume(returning: tempFile)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            downloadTask?.resume()
        }
    }
    
    private func installDownloadedApp(from zipURL: URL) async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ollama-install")
        
        // Create temp directory
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // Cleanup
            try? FileManager.default.removeItem(at: tempDir)
            try? FileManager.default.removeItem(at: zipURL)
        }
        
        // Unzip
        let unzipProcess = Process()
        unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzipProcess.arguments = ["-q", zipURL.path, "-d", tempDir.path]
        
        try unzipProcess.run()
        unzipProcess.waitUntilExit()
        
        guard unzipProcess.terminationStatus == 0 else {
            throw OllamaInstallerError.extractionFailed
        }
        
        // Find Ollama.app in extracted contents
        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        guard let ollamaApp = contents.first(where: { $0.lastPathComponent == "Ollama.app" }) else {
            throw OllamaInstallerError.appNotFoundInArchive
        }
        
        // Request permission to move to Applications
        let alert = NSAlert()
        alert.messageText = "Install Ollama"
        alert.informativeText = "Gemi needs to install Ollama to /Applications. This requires your permission."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")
        
        let response = await MainActor.run { alert.runModal() }
        
        guard response == .alertFirstButtonReturn else {
            throw OllamaInstallerError.userCancelled
        }
        
        // Move to Applications
        if FileManager.default.fileExists(atPath: ollamaAppPath) {
            try FileManager.default.removeItem(atPath: ollamaAppPath)
        }
        
        try FileManager.default.moveItem(at: ollamaApp, to: URL(fileURLWithPath: ollamaAppPath))
        
        // Make CLI symlink executable
        let makeExecutableProcess = Process()
        makeExecutableProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
        makeExecutableProcess.arguments = ["+x", ollamaCliPath]
        try? makeExecutableProcess.run()
        makeExecutableProcess.waitUntilExit()
    }
}

// MARK: - URLSessionDownloadDelegate

extension OllamaInstaller: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // This is handled in the downloadTask completion handler
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            self.downloadProgress = progress
            self.installationStatus = .downloading(progress: progress)
            
            let formatter = ByteCountFormatter()
            formatter.countStyle = .binary
            let downloaded = formatter.string(fromByteCount: totalBytesWritten)
            let total = formatter.string(fromByteCount: totalBytesExpectedToWrite)
            self.downloadStatus = "Downloading Ollama: \(downloaded) / \(total)"
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.installationStatus = .error(error.localizedDescription)
            }
        }
    }
}

// MARK: - Errors

enum OllamaInstallerError: LocalizedError {
    case invalidDownloadURL
    case downloadFailed
    case extractionFailed
    case appNotFoundInArchive
    case installationFailed
    case serverStartFailed
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidDownloadURL:
            return "Invalid download URL"
        case .downloadFailed:
            return "Failed to download Ollama"
        case .extractionFailed:
            return "Failed to extract Ollama app"
        case .appNotFoundInArchive:
            return "Ollama app not found in download"
        case .installationFailed:
            return "Failed to install Ollama"
        case .serverStartFailed:
            return "Failed to start Ollama server"
        case .userCancelled:
            return "Installation cancelled by user"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .downloadFailed:
            return "Check your internet connection and try again"
        case .installationFailed, .serverStartFailed:
            return "Try installing Ollama manually from ollama.com"
        case .userCancelled:
            return "You can install Ollama manually or try again later"
        default:
            return "Please try again or install Ollama manually"
        }
    }
}