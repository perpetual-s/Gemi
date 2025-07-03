#!/usr/bin/env swift

import Foundation

// ANSI color codes for better output
let green = "\u{001B}[0;32m"
let red = "\u{001B}[0;31m"
let yellow = "\u{001B}[0;33m"
let blue = "\u{001B}[0;34m"
let reset = "\u{001B}[0m"

print("\(blue)=== Ollama Auto-Launch Test ===\(reset)\n")

// Test 1: Check if Ollama is installed
print("\(yellow)Test 1: Checking Ollama installation...\(reset)")

let ollamaPaths = [
    "/usr/local/bin/ollama",
    "/opt/homebrew/bin/ollama",
    "/usr/bin/ollama",
    "\(NSHomeDirectory())/.ollama/bin/ollama",
    "/Applications/Ollama.app/Contents/MacOS/ollama"
]

var ollamaPath: String? = nil
for path in ollamaPaths {
    if FileManager.default.fileExists(atPath: path) {
        ollamaPath = path
        print("\(green)✓ Found Ollama at: \(path)\(reset)")
        break
    }
}

// Also try 'which' command
if ollamaPath == nil {
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
                ollamaPath = path
                print("\(green)✓ Found Ollama via 'which' at: \(path)\(reset)")
            }
        }
    } catch {
        print("\(red)✗ Error running 'which' command: \(error)\(reset)")
    }
}

if ollamaPath == nil {
    print("\(red)✗ Ollama not found in any expected location\(reset)")
    print("  Please install Ollama from https://ollama.ai")
    exit(1)
}

// Test 2: Check if Ollama is already running
print("\n\(yellow)Test 2: Checking if Ollama is already running...\(reset)")

func isOllamaRunning() -> Bool {
    let url = URL(string: "http://localhost:11434/api/tags")!
    var request = URLRequest(url: url)
    request.timeoutInterval = 5.0
    
    let semaphore = DispatchSemaphore(value: 0)
    var isRunning = false
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
            isRunning = true
        }
        semaphore.signal()
    }
    
    task.resume()
    semaphore.wait()
    
    return isRunning
}

if isOllamaRunning() {
    print("\(green)✓ Ollama is already running on port 11434\(reset)")
    print("  No need to launch it again.")
} else {
    print("\(yellow)○ Ollama is not currently running\(reset)")
    
    // Test 3: Try to launch Ollama
    print("\n\(yellow)Test 3: Attempting to launch Ollama...\(reset)")
    
    let process = Process()
    process.launchPath = ollamaPath
    process.arguments = ["serve"]
    
    // Set up pipes to capture output
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    
    // Set environment
    var environment = ProcessInfo.processInfo.environment
    environment["OLLAMA_HOST"] = "127.0.0.1:11434"
    process.environment = environment
    
    do {
        try process.run()
        print("\(green)✓ Ollama process started with PID: \(process.processIdentifier)\(reset)")
        
        // Wait a bit for Ollama to start
        print("  Waiting for Ollama to be ready...")
        
        var attempts = 0
        var ready = false
        
        while attempts < 30 && !ready {
            Thread.sleep(forTimeInterval: 1.0)
            attempts += 1
            
            if isOllamaRunning() {
                ready = true
                print("\(green)✓ Ollama is now ready and accepting connections!\(reset)")
            } else if !process.isRunning {
                print("\(red)✗ Ollama process terminated unexpectedly\(reset)")
                break
            } else {
                print("  Still waiting... (attempt \(attempts)/30)")
            }
        }
        
        if !ready {
            print("\(red)✗ Ollama failed to become ready within 30 seconds\(reset)")
            process.terminate()
        }
        
        // Clean up
        if process.isRunning {
            print("\n\(yellow)Stopping Ollama process...\(reset)")
            process.terminate()
            process.waitUntilExit()
            print("\(green)✓ Ollama process stopped\(reset)")
        }
        
    } catch {
        print("\(red)✗ Failed to launch Ollama: \(error)\(reset)")
    }
}

// Test 4: Check for model installation
print("\n\(yellow)Test 4: Checking for required models...\(reset)")

if isOllamaRunning() {
    let url = URL(string: "http://localhost:11434/api/tags")!
    let semaphore = DispatchSemaphore(value: 0)
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = json["models"] as? [[String: Any]] {
            
            let modelNames = models.compactMap { $0["name"] as? String }
            print("  Installed models: \(modelNames.joined(separator: ", "))")
            
            let hasGemma = modelNames.contains { $0.hasPrefix("gemma3n") }
            let hasEmbedding = modelNames.contains { $0.hasPrefix("nomic-embed-text") }
            
            if hasGemma {
                print("\(green)✓ Gemma 3n model is installed\(reset)")
            } else {
                print("\(red)✗ Gemma 3n model is NOT installed\(reset)")
                print("  Run: ollama pull gemma3n:latest")
            }
            
            if hasEmbedding {
                print("\(green)✓ Embedding model is installed\(reset)")
            } else {
                print("\(red)✗ Embedding model is NOT installed\(reset)")
                print("  Run: ollama pull nomic-embed-text:latest")
            }
        }
        semaphore.signal()
    }
    
    task.resume()
    semaphore.wait()
}

print("\n\(blue)=== Test Complete ===\(reset)")