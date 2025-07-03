//
//  OllamaLauncher.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/3/25.
//

import Foundation
import SwiftUI
import AppKit
import os.log

/// OllamaLauncher manages the lifecycle of the Ollama server process
@Observable
@MainActor
final class OllamaLauncher {
    
    // MARK: - Singleton
    
    static let shared = OllamaLauncher()
    
    // MARK: - Published Properties
    
    /// Current status of the Ollama service
    var status: OllamaStatus = .checking
    
    /// Error message if any
    var errorMessage: String?
    
    /// Whether we're currently launching Ollama
    var isLaunching: Bool = false
    
    /// The Ollama server process (if we started it)
    private var ollamaProcess: Process?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.gemi.app", category: "OllamaLauncher")
    private let ollamaPort = 11434
    private let maxLaunchAttempts = 3
    private let launchTimeout: TimeInterval = 30
    
    // Common Ollama installation paths
    private let ollamaPaths = [
        "/usr/local/bin/ollama",
        "/opt/homebrew/bin/ollama",
        "/usr/bin/ollama",
        "\(NSHomeDirectory())/.ollama/bin/ollama",
        "/Applications/Ollama.app/Contents/MacOS/ollama"
    ]
    
    // MARK: - Initialization
    
    private init() {
        // Start checking Ollama status when the launcher is created
        Task {
            await checkAndLaunchOllama()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check Ollama status and launch if necessary
    @MainActor
    func checkAndLaunchOllama() async {
        logger.info("Starting Ollama check and launch sequence")
        
        status = .checking
        errorMessage = nil
        
        // First check if Ollama is already running
        if await isOllamaRunning() {
            logger.info("Ollama is already running")
            status = .running
            return
        }
        
        // Check if Ollama is installed
        guard let ollamaPath = findOllamaExecutable() else {
            logger.error("Ollama not found in any expected location")
            status = .notInstalled
            errorMessage = "Ollama is not installed. Please install from ollama.ai"
            return
        }
        
        logger.info("Found Ollama at: \(ollamaPath)")
        
        // First try to launch via NSWorkspace (sandbox-friendly)
        if await tryLaunchViaWorkspace() {
            return
        }
        
        // Fallback to direct process launch
        await launchOllama(at: ollamaPath)
    }
    
    /// Stop the Ollama process if we started it
    func stopOllama() {
        guard let process = ollamaProcess, process.isRunning else {
            return
        }
        
        logger.info("Stopping Ollama process")
        process.terminate()
        ollamaProcess = nil
        status = .stopped
    }
    
    /// Restart Ollama
    @MainActor
    func restartOllama() async {
        stopOllama()
        await checkAndLaunchOllama()
    }
    
    // MARK: - Private Methods
    
    /// Try to launch Ollama via NSWorkspace (sandbox-friendly)
    @MainActor
    private func tryLaunchViaWorkspace() async -> Bool {
        logger.info("Attempting to launch Ollama via NSWorkspace")
        
        // Check if Ollama.app exists
        let ollamaAppPath = "/Applications/Ollama.app"
        guard FileManager.default.fileExists(atPath: ollamaAppPath) else {
            logger.info("Ollama.app not found, skipping NSWorkspace launch")
            return false
        }
        
        status = .launching
        isLaunching = true
        
        defer {
            isLaunching = false
        }
        
        let launcher = OllamaAppLauncher.shared
        if await launcher.launchOllamaApp() {
            status = .running
            errorMessage = nil
            logger.info("Successfully launched Ollama via NSWorkspace")
            return true
        }
        
        return false
    }
    
    /// Check if Ollama is running by testing the API endpoint
    private func isOllamaRunning() async -> Bool {
        let url = URL(string: "http://localhost:\(ollamaPort)/api/tags")!
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return true
            }
        } catch {
            // Not running or not accessible
        }
        
        return false
    }
    
    /// Find the Ollama executable
    private func findOllamaExecutable() -> String? {
        let fileManager = FileManager.default
        
        // Check common installation paths
        for path in ollamaPaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try using 'which' command as fallback
        let whichTask = Process()
        whichTask.launchPath = "/usr/bin/which"
        whichTask.arguments = ["ollama"]
        
        let pipe = Pipe()
        whichTask.standardOutput = pipe
        whichTask.standardError = Pipe()
        
        do {
            try whichTask.run()
            whichTask.waitUntilExit()
            
            if whichTask.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            logger.error("Failed to run 'which' command: \(error)")
        }
        
        return nil
    }
    
    /// Launch Ollama server
    @MainActor
    private func launchOllama(at path: String) async {
        logger.info("Launching Ollama server")
        
        status = .launching
        isLaunching = true
        
        defer {
            isLaunching = false
        }
        
        for attempt in 1...maxLaunchAttempts {
            logger.info("Launch attempt \(attempt) of \(self.maxLaunchAttempts)")
            
            let process = Process()
            process.launchPath = path
            process.arguments = ["serve"]
            
            // Set up pipes to capture output
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Set environment to ensure it runs properly
            var environment = ProcessInfo.processInfo.environment
            environment["OLLAMA_HOST"] = "127.0.0.1:\(ollamaPort)"
            process.environment = environment
            
            do {
                try process.run()
                ollamaProcess = process
                
                // Monitor the output asynchronously
                Task {
                    await monitorProcessOutput(outputPipe: outputPipe, errorPipe: errorPipe)
                }
                
                // Wait for Ollama to be ready
                let startTime = Date()
                var isReady = false
                
                while Date().timeIntervalSince(startTime) < launchTimeout && !isReady {
                    if await isOllamaRunning() {
                        isReady = true
                        break
                    }
                    
                    // Check if process is still running
                    if !process.isRunning {
                        logger.error("Ollama process terminated unexpectedly")
                        break
                    }
                    
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
                
                if isReady {
                    logger.info("Ollama successfully launched and ready")
                    status = .running
                    errorMessage = nil
                    return
                } else if !process.isRunning {
                    logger.error("Ollama process failed to stay running")
                    status = .failed
                    errorMessage = "Ollama failed to start. Check if another instance is running."
                } else {
                    logger.error("Ollama launch timeout")
                    process.terminate()
                    status = .failed
                    errorMessage = "Ollama took too long to start"
                }
                
            } catch {
                logger.error("Failed to launch Ollama: \(error)")
                status = .failed
                errorMessage = "Failed to launch Ollama: \(error.localizedDescription)"
            }
            
            // Wait before retry
            if attempt < maxLaunchAttempts {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
        
        // All attempts failed
        if status != .running {
            status = .failed
            errorMessage = errorMessage ?? "Failed to launch Ollama after \(maxLaunchAttempts) attempts"
        }
    }
    
    /// Monitor process output for debugging
    private func monitorProcessOutput(outputPipe: Pipe, errorPipe: Pipe) async {
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        
        // Monitor standard output
        Task {
            while true {
                let data = outputHandle.availableData
                if data.isEmpty {
                    break
                }
                if let output = String(data: data, encoding: .utf8) {
                    logger.debug("Ollama output: \(output)")
                }
            }
        }
        
        // Monitor error output
        Task {
            while true {
                let data = errorHandle.availableData
                if data.isEmpty {
                    break
                }
                if let error = String(data: data, encoding: .utf8) {
                    logger.error("Ollama error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Note: Cannot access @MainActor properties from deinit
        // The process will be cleaned up automatically when the app terminates
        // or can be manually stopped via stopOllama() before deinitialization
    }
}

// MARK: - Supporting Types

enum OllamaStatus: String, CaseIterable {
    case checking = "Checking..."
    case notInstalled = "Not Installed"
    case launching = "Launching..."
    case running = "Running"
    case failed = "Failed"
    case stopped = "Stopped"
    
    var icon: String {
        switch self {
        case .checking: return "hourglass"
        case .notInstalled: return "xmark.circle.fill"
        case .launching: return "arrow.triangle.2.circlepath"
        case .running: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .stopped: return "stop.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .checking: return .secondary
        case .notInstalled: return .orange
        case .launching: return .blue
        case .running: return .green
        case .failed: return .red
        case .stopped: return .gray
        }
    }
    
    var needsUserAction: Bool {
        switch self {
        case .notInstalled, .failed:
            return true
        default:
            return false
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Show Ollama status banner when needed
    func ollamaStatusBanner() -> some View {
        self.overlay(alignment: .top) {
            OllamaStatusBanner()
        }
    }
}

/// Status banner view for showing Ollama status
struct OllamaStatusBanner: View {
    @State private var launcher = OllamaLauncher.shared
    @State private var showingDetails = false
    
    var body: some View {
        if launcher.status.needsUserAction || launcher.status == .launching {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: launcher.status.icon)
                        .foregroundStyle(launcher.status.color)
                        .font(.system(size: 16))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ollama \(launcher.status.rawValue)")
                            .font(.system(size: 13, weight: .medium))
                        
                        if let error = launcher.errorMessage {
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    if launcher.status == .launching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if launcher.status.needsUserAction {
                        Button("Details") {
                            showingDetails = true
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 11))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                
                Divider()
            }
            .fixedSize(horizontal: false, vertical: true)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.3), value: launcher.status)
            .sheet(isPresented: $showingDetails) {
                OllamaSetupView(isPresented: $showingDetails, ollamaService: OllamaService.shared)
            }
        }
    }
}

