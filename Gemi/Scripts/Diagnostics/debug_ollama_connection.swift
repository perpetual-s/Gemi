#!/usr/bin/env swift

import Foundation

// Test Ollama connection
func checkOllamaConnection() async {
    print("Testing Ollama connection...")
    
    let baseURL = "http://localhost:11434"
    guard let url = URL(string: "\(baseURL)/api/tags") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.timeoutInterval = 5.0
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Response Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                print("✅ Ollama is running!")
                
                // Try to parse the response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["models"] as? [[String: Any]] {
                    print("\nInstalled models:")
                    for model in models {
                        if let name = model["name"] as? String {
                            print("  - \(name)")
                        }
                    }
                }
            } else {
                print("❌ Unexpected status code: \(httpResponse.statusCode)")
            }
        }
    } catch {
        print("❌ Connection failed: \(error)")
        print("\nTroubleshooting:")
        print("1. Make sure Ollama is installed: https://ollama.ai")
        print("2. Start Ollama service: ollama serve")
        print("3. Check if it's running on port 11434")
    }
}

// Run the check
Task {
    await checkOllamaConnection()
    exit(0)
}

// Keep the script running
RunLoop.main.run()