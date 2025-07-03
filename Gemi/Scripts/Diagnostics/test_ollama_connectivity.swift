#!/usr/bin/env swift

import Foundation

// Test script to diagnose Ollama connectivity issues
// Run with: swift test_ollama_connectivity.swift

print("🔍 Ollama Connectivity Diagnostic Tool")
print("=====================================\n")

// Configuration
let baseURL = "http://localhost:11434"
let expectedModels = [
    "gemma3n:latest",     // Main model (as specified in OllamaService)
    "gemma2:2b",          // Alternative model (as shown in OllamaSetupView)
    "nomic-embed-text"    // Embedding model
]

// MARK: - Test 1: Basic Connectivity
print("1️⃣ Testing basic connectivity to Ollama...")
func testBasicConnectivity() async -> Bool {
    do {
        let url = URL(string: "\(baseURL)/api/tags")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   ✅ Status Code: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 200 {
                print("   ✅ Ollama server is running!")
                return true
            } else {
                print("   ❌ Unexpected status code")
                return false
            }
        }
    } catch {
        print("   ❌ Connection failed: \(error.localizedDescription)")
        print("   💡 Tip: Make sure Ollama is running with 'ollama serve'")
        return false
    }
    return false
}

// MARK: - Test 2: List Available Models
print("\n2️⃣ Checking installed models...")
func checkInstalledModels() async {
    do {
        let url = URL(string: "\(baseURL)/api/tags")!
        let (data, _) = try await URLSession.shared.data(from: url)
        
        struct ModelList: Codable {
            let models: [Model]
        }
        
        struct Model: Codable {
            let name: String
            let size: Int64
            let digest: String
            let modified_at: String
        }
        
        let decoder = JSONDecoder()
        let modelList = try decoder.decode(ModelList.self, from: data)
        
        if modelList.models.isEmpty {
            print("   ⚠️  No models installed")
            print("   💡 Tip: Install models with:")
            for model in expectedModels {
                print("      ollama pull \(model)")
            }
        } else {
            print("   📦 Installed models:")
            for model in modelList.models {
                let sizeInMB = Double(model.size) / 1_000_000
                print("      - \(model.name) (Size: \(String(format: "%.1f", sizeInMB)) MB)")
            }
            
            // Check for expected models
            print("\n   🔍 Checking for required models:")
            let installedNames = modelList.models.map { $0.name }
            
            for expectedModel in expectedModels {
                let isInstalled = installedNames.contains { name in
                    name == expectedModel || name.hasPrefix(expectedModel.components(separatedBy: ":").first ?? "")
                }
                
                if isInstalled {
                    print("      ✅ \(expectedModel) - Found")
                } else {
                    print("      ❌ \(expectedModel) - Not found")
                    print("         💡 Install with: ollama pull \(expectedModel)")
                }
            }
        }
        
    } catch {
        print("   ❌ Failed to list models: \(error.localizedDescription)")
    }
}

// MARK: - Test 3: Test Model Generation
print("\n3️⃣ Testing model generation...")
func testModelGeneration() async {
    // Try to find an available model
    let modelsToTry = ["gemma3n:latest", "gemma2:2b", "gemma:2b", "llama2", "mistral"]
    
    for modelName in modelsToTry {
        print("   🧪 Trying model: \(modelName)")
        
        do {
            let url = URL(string: "\(baseURL)/api/generate")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let requestBody = [
                "model": modelName,
                "prompt": "Hello! Please respond with a simple greeting.",
                "stream": false
            ] as [String : Any]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let responseText = json["response"] as? String {
                        print("   ✅ Model \(modelName) responded: \(responseText.prefix(50))...")
                        return
                    }
                } else if httpResponse.statusCode == 404 {
                    print("   ⚠️  Model \(modelName) not found")
                } else {
                    print("   ❌ Error: Status \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("   ❌ Failed: \(error.localizedDescription)")
        }
    }
    
    print("   ❌ No working models found!")
}

// MARK: - Test 4: Check CORS Headers
print("\n4️⃣ Checking CORS configuration...")
func checkCORSHeaders() async {
    do {
        let url = URL(string: "\(baseURL)/api/tags")!
        var request = URLRequest(url: url)
        request.setValue("http://localhost:3000", forHTTPHeaderField: "Origin")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   📋 Response Headers:")
            
            // Check for CORS headers
            let corsHeaders = [
                "Access-Control-Allow-Origin",
                "Access-Control-Allow-Methods",
                "Access-Control-Allow-Headers"
            ]
            
            for header in corsHeaders {
                if let value = httpResponse.value(forHTTPHeaderField: header) {
                    print("      ✅ \(header): \(value)")
                } else {
                    print("      ⚠️  \(header): Not set")
                }
            }
            
            // Ollama typically allows all origins by default
            if httpResponse.value(forHTTPHeaderField: "Access-Control-Allow-Origin") != nil {
                print("   ✅ CORS is properly configured")
            } else {
                print("   ⚠️  CORS headers might need configuration")
            }
        }
    } catch {
        print("   ❌ Failed to check CORS: \(error.localizedDescription)")
    }
}

// MARK: - Test 5: Environment Check
print("\n5️⃣ Checking environment...")
func checkEnvironment() {
    print("   🖥  System Info:")
    print("      - OS: macOS")
    print("      - Swift Version: \(#file.contains("swift") ? "✅ Swift is available" : "❌ Swift not detected")")
    
    // Check if Ollama process is running
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", "ps aux | grep -i ollama | grep -v grep"]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    
    do {
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if !output.isEmpty {
            print("   ✅ Ollama process found running")
        } else {
            print("   ⚠️  Ollama process not detected")
            print("   💡 Start Ollama with: ollama serve")
        }
    } catch {
        print("   ⚠️  Could not check for Ollama process")
    }
}

// MARK: - Run All Tests
Task {
    let isConnected = await testBasicConnectivity()
    
    if isConnected {
        await checkInstalledModels()
        await testModelGeneration()
        await checkCORSHeaders()
    }
    
    checkEnvironment()
    
    print("\n📊 Diagnostic Summary")
    print("====================")
    print("🔗 Ollama API Endpoint: \(baseURL)")
    print("📦 Expected Models:")
    for model in expectedModels {
        print("   - \(model)")
    }
    print("\n💡 Quick Fix Commands:")
    print("   1. Start Ollama: ollama serve")
    print("   2. Install main model: ollama pull gemma2:2b")
    print("   3. Install embedding model: ollama pull nomic-embed-text")
    print("   4. List models: ollama list")
    print("   5. Test model: curl -X POST http://localhost:11434/api/generate -d '{\"model\": \"gemma2:2b\", \"prompt\": \"Hello\", \"stream\": false}'")
    
    exit(0)
}

RunLoop.main.run()