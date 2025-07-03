// Ollama Auto-Launch Solution for macOS
// Note: This requires app to have proper entitlements

import Foundation
import SwiftUI
import os.log

class OllamaLauncher {
    static let shared = OllamaLauncher()
    private let logger = Logger(subsystem: "com.gemi.app", category: "OllamaLauncher")
    
    // Check if Ollama is installed
    func isOllamaInstalled() -> Bool {
        let fileManager = FileManager.default
        
        // Common installation paths
        let paths = [
            "/usr/local/bin/ollama",
            "/opt/homebrew/bin/ollama",
            "/Applications/Ollama.app/Contents/MacOS/ollama"
        ]
        
        for path in paths {
            if fileManager.fileExists(atPath: path) {
                logger.info("Found Ollama at: \(path)")
                return true
            }
        }
        
        // Check if in PATH
        let process = Process()
        process.launchPath = "/usr/bin/which"
        process.arguments = ["ollama"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                if let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8),
                   !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logger.info("Found Ollama in PATH: \(output)")
                    return true
                }
            }
        } catch {
            logger.error("Error checking for Ollama: \(error)")
        }
        
        return false
    }
    
    // Launch Ollama server
    @discardableResult
    func launchOllama() -> Bool {
        logger.info("Attempting to launch Ollama server...")
        
        // First check if already running
        if isOllamaRunning() {
            logger.info("Ollama is already running")
            return true
        }
        
        // Try to launch Ollama
        let process = Process()
        
        // Try different launch methods
        let launchCommands = [
            // Method 1: Direct binary
            (path: "/usr/local/bin/ollama", args: ["serve"]),
            (path: "/opt/homebrew/bin/ollama", args: ["serve"]),
            
            // Method 2: Using shell
            (path: "/bin/sh", args: ["-c", "ollama serve"]),
            
            // Method 3: Launch macOS app
            (path: "/usr/bin/open", args: ["-a", "Ollama"])
        ]
        
        for (path, args) in launchCommands {
            if FileManager.default.fileExists(atPath: path) {
                process.launchPath = path
                process.arguments = args
                
                // Set up environment
                var environment = ProcessInfo.processInfo.environment
                environment["HOME"] = NSHomeDirectory()
                process.environment = environment
                
                // Redirect output to avoid blocking
                process.standardOutput = Pipe()
                process.standardError = Pipe()
                
                do {
                    try process.run()
                    
                    // Give it a moment to start
                    Thread.sleep(forTimeInterval: 2.0)
                    
                    // Check if it started successfully
                    if isOllamaRunning() {
                        logger.info("Successfully launched Ollama using: \(path)")
                        return true
                    }
                } catch {
                    logger.error("Failed to launch Ollama with \(path): \(error)")
                }
            }
        }
        
        logger.error("Failed to launch Ollama server")
        return false
    }
    
    // Check if Ollama server is running
    func isOllamaRunning() -> Bool {
        let url = URL(string: "http://localhost:11434/api/tags")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        
        let semaphore = DispatchSemaphore(value: 0)
        var isRunning = false
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                isRunning = true
            }
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        return isRunning
    }
    
    // Stop Ollama server
    func stopOllama() {
        logger.info("Stopping Ollama server...")
        
        let process = Process()
        process.launchPath = "/usr/bin/pkill"
        process.arguments = ["-f", "ollama serve"]
        
        do {
            try process.run()
            process.waitUntilExit()
            logger.info("Ollama server stop signal sent")
        } catch {
            logger.error("Failed to stop Ollama: \(error)")
        }
    }
}

// SwiftUI View for Ollama Setup
struct OllamaSetupView: View {
    @State private var isChecking = true
    @State private var ollamaStatus: OllamaStatus = .checking
    @State private var showManualInstructions = false
    
    enum OllamaStatus {
        case checking
        case notInstalled
        case notRunning
        case launching
        case running
        case error(String)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Status icon
            statusIcon
            
            // Status message
            Text(statusMessage)
                .font(.title2)
                .multilineTextAlignment(.center)
            
            // Action button
            actionButton
            
            // Manual instructions toggle
            if ollamaStatus != .running {
                Button("Show manual setup instructions") {
                    showManualInstructions.toggle()
                }
                .buttonStyle(.link)
            }
            
            if showManualInstructions {
                manualInstructions
            }
        }
        .padding(40)
        .frame(width: 500)
        .onAppear {
            checkOllamaStatus()
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch ollamaStatus {
        case .checking, .launching:
            ProgressView()
                .scaleEffect(1.5)
        case .notInstalled:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
        case .notRunning:
            Image(systemName: "play.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
        case .running:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
        }
    }
    
    private var statusMessage: String {
        switch ollamaStatus {
        case .checking:
            return "Checking Ollama status..."
        case .notInstalled:
            return "Ollama is not installed"
        case .notRunning:
            return "Ollama is installed but not running"
        case .launching:
            return "Starting Ollama server..."
        case .running:
            return "Ollama is running!"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch ollamaStatus {
        case .checking, .launching:
            EmptyView()
        case .notInstalled:
            Link("Download Ollama", destination: URL(string: "https://ollama.ai")!)
                .buttonStyle(.borderedProminent)
        case .notRunning:
            Button("Start Ollama") {
                launchOllama()
            }
            .buttonStyle(.borderedProminent)
        case .running:
            Button("Continue") {
                // Dismiss or continue
            }
            .buttonStyle(.borderedProminent)
        case .error:
            Button("Retry") {
                checkOllamaStatus()
            }
            .buttonStyle(.bordered)
        }
    }
    
    @ViewBuilder
    private var manualInstructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Setup Instructions:")
                .font(.headline)
            
            Text("1. Open Terminal")
            Text("2. Install Ollama: curl -fsSL https://ollama.ai/install.sh | sh")
            Text("3. Start server: ollama serve")
            Text("4. In another terminal: ollama pull gemma3n:latest")
            Text("5. Also pull: ollama pull nomic-embed-text:latest")
        }
        .font(.system(.body, design: .monospaced))
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func checkOllamaStatus() {
        Task {
            await MainActor.run {
                ollamaStatus = .checking
            }
            
            // Check if installed
            if !OllamaLauncher.shared.isOllamaInstalled() {
                await MainActor.run {
                    ollamaStatus = .notInstalled
                }
                return
            }
            
            // Check if running
            if !OllamaLauncher.shared.isOllamaRunning() {
                await MainActor.run {
                    ollamaStatus = .notRunning
                }
                return
            }
            
            await MainActor.run {
                ollamaStatus = .running
            }
        }
    }
    
    private func launchOllama() {
        Task {
            await MainActor.run {
                ollamaStatus = .launching
            }
            
            let success = OllamaLauncher.shared.launchOllama()
            
            await MainActor.run {
                if success {
                    ollamaStatus = .running
                } else {
                    ollamaStatus = .error("Failed to start Ollama")
                }
            }
        }
    }
}

// IMPORTANT: App Sandbox Considerations
/*
 For auto-launch to work, the app needs proper entitlements:
 
 1. In your .entitlements file, you may need:
    - com.apple.security.inherit (to inherit parent process permissions)
    - com.apple.security.temporary-exception.files.absolute-path.read-write
    
 2. If sandboxed, you might need to:
    - Request user permission
    - Use XPC services
    - Or disable sandboxing for development
 
 3. Alternative approach: Use AppleScript
    ```
    tell application "Terminal"
        do script "ollama serve"
    end tell
    ```
*/