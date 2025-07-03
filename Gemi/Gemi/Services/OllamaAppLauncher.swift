//
//  OllamaAppLauncher.swift
//  Gemi
//
//  Alternative Ollama launcher that works with macOS sandboxing
//

import Foundation
import AppKit
import os.log

/// Alternative launcher that uses NSWorkspace for better sandbox compatibility
@Observable
@MainActor
final class OllamaAppLauncher {
    
    static let shared = OllamaAppLauncher()
    
    private let logger = Logger(subsystem: "com.gemi.app", category: "OllamaAppLauncher")
    
    /// Launch Ollama using NSWorkspace (sandbox-friendly)
    func launchOllamaApp() async -> Bool {
        logger.info("Attempting to launch Ollama.app")
        
        // First check if Ollama.app exists
        let ollamaAppPath = "/Applications/Ollama.app"
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: ollamaAppPath) else {
            logger.error("Ollama.app not found at \(ollamaAppPath)")
            return false
        }
        
        // Use NSWorkspace to launch the app
        let workspace = NSWorkspace.shared
        let appURL = URL(fileURLWithPath: ollamaAppPath)
        
        do {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false // Don't bring to front
            config.hides = true // Launch in background
            
            let app = try await workspace.openApplication(at: appURL, configuration: config)
            logger.info("Successfully launched Ollama.app with PID: \(app.processIdentifier)")
            
            // Wait for Ollama to be ready
            return await waitForOllama()
            
        } catch {
            logger.error("Failed to launch Ollama.app: \(error)")
            return false
        }
    }
    
    /// Check if Ollama.app is running
    func isOllamaAppRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == "com.ollama.ollama" ||
            app.localizedName == "Ollama" ||
            app.bundleURL?.path.contains("Ollama.app") == true
        }
    }
    
    /// Wait for Ollama API to be ready
    private func waitForOllama(maxAttempts: Int = 30) async -> Bool {
        logger.info("Waiting for Ollama API to be ready...")
        
        for attempt in 1...maxAttempts {
            if await isOllamaAPIReady() {
                logger.info("Ollama API is ready after \(attempt) attempts")
                return true
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        logger.error("Ollama API did not become ready after \(maxAttempts) attempts")
        return false
    }
    
    /// Check if Ollama API is responding
    private func isOllamaAPIReady() async -> Bool {
        let url = URL(string: "http://localhost:11434/api/tags")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return true
            }
        } catch {
            // API not ready yet
        }
        
        return false
    }
    
    /// Open Ollama preferences/settings
    func openOllamaPreferences() {
        if let url = URL(string: "ollama://preferences") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Open Ollama.ai website for download
    func openOllamaWebsite() {
        if let url = URL(string: "https://ollama.ai") {
            NSWorkspace.shared.open(url)
        }
    }
}