import Foundation

/// Diagnostic utility for debugging model loading issues
@MainActor
class ModelDiagnostics {
    
    /// Check model files and print diagnostic information
    static func diagnoseModelFiles() {
        print("\n=== Gemma 3n Model Diagnostics ===\n")
        
        // Check HuggingFace token
        print("🔐 Authentication Status:")
        if let token = SettingsManager.shared.getHuggingFaceToken() {
            print("  ✓ HuggingFace token found (starts with: \(String(token.prefix(7)))...)")
        } else {
            print("  ✗ No HuggingFace token found!")
            print("  → Check .env file or add token in Settings")
        }
        
        // Check environment config
        print("\n📁 Environment Configuration:")
        print("  .env search paths:")
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil) {
            print("    ✓ Found in bundle: \(envPath)")
        } else {
            print("    ✗ Not found in bundle")
        }
        if let resourcesURL = Bundle.main.resourceURL?.appendingPathComponent(".env") {
            print("    → Resources path: \(resourcesURL.path)")
            print("    → Exists: \(FileManager.default.fileExists(atPath: resourcesURL.path))")
        }
        
        let modelCache = ModelCache.shared
        let modelPath = modelCache.modelPath
        
        print("\n📦 Model Storage:")
        print("  Model path: \(modelPath.path)")
        print("  Directory exists: \(FileManager.default.fileExists(atPath: modelPath.path))")
        
        // Check required files
        let requiredFiles = [
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "model-00001-of-00004.safetensors",
            "model-00002-of-00004.safetensors",
            "model-00003-of-00004.safetensors",
            "model-00004-of-00004.safetensors"
        ]
        
        print("\nChecking required files:")
        for file in requiredFiles {
            let filePath = modelPath.appendingPathComponent(file)
            let exists = FileManager.default.fileExists(atPath: filePath.path)
            let size = getFileSize(at: filePath)
            print("  \(file): \(exists ? "✓" : "✗") \(size)")
        }
        
        // Try to read and parse config.json
        print("\nChecking config.json:")
        let configPath = modelPath.appendingPathComponent("config.json")
        if FileManager.default.fileExists(atPath: configPath.path) {
            do {
                let data = try Data(contentsOf: configPath)
                print("  File size: \(data.count) bytes")
                
                // Try to parse as generic JSON first
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("  JSON structure:")
                    for (key, value) in json.sorted(by: { $0.key < $1.key }) {
                        let valueType = type(of: value)
                        print("    - \(key): \(valueType)")
                    }
                    
                    // Print specific fields we're looking for
                    print("\n  Expected fields:")
                    let expectedFields = [
                        "model_type",
                        "num_hidden_layers",
                        "hidden_size",
                        "num_attention_heads",
                        "vocab_size"
                    ]
                    
                    for field in expectedFields {
                        if let value = json[field] {
                            print("    - \(field): \(value)")
                        } else {
                            print("    - \(field): MISSING")
                        }
                    }
                } else {
                    print("  Failed to parse as JSON")
                    // Print first 500 characters
                    if let content = String(data: data, encoding: .utf8) {
                        print("  Content preview: \(String(content.prefix(500)))")
                    }
                }
                
                // Try to decode as ModelConfig
                print("\n  Trying to decode as ModelConfig:")
                do {
                    let config = try JSONDecoder().decode(ModelConfig.self, from: data)
                    print("  ✓ Successfully decoded!")
                    print("    - Model type: \(config.modelType)")
                    print("    - Layers: \(config.actualNumLayers)")
                    print("    - Hidden size: \(config.actualHiddenSize)")
                    print("    - Vocab size: \(config.vocabSize)")
                } catch {
                    print("  ✗ Failed to decode: \(error)")
                }
                
            } catch {
                print("  Error reading file: \(error)")
            }
        } else {
            print("  File not found!")
        }
        
        // Check tokenizer.json
        print("\nChecking tokenizer.json:")
        let tokenizerPath = modelPath.appendingPathComponent("tokenizer.json")
        if FileManager.default.fileExists(atPath: tokenizerPath.path) {
            do {
                let data = try Data(contentsOf: tokenizerPath)
                print("  File size: \(data.count) bytes")
                
                // Check if it's valid JSON
                if let _ = try? JSONSerialization.jsonObject(with: data) {
                    print("  ✓ Valid JSON")
                } else {
                    print("  ✗ Invalid JSON")
                }
            } catch {
                print("  Error reading file: \(error)")
            }
        } else {
            print("  File not found!")
        }
        
        print("\n=== End Diagnostics ===\n")
    }
    
    /// Test HuggingFace API authentication
    static func testHuggingFaceAuthentication() async {
        print("\n=== Testing HuggingFace Authentication ===\n")
        
        let testURL = "https://huggingface.co/api/models/google/gemma-3n-E4B-it"
        
        do {
            var request = URLRequest(url: URL(string: testURL)!)
            request.httpMethod = "GET"
            request.setValue("Gemi/1.0", forHTTPHeaderField: "User-Agent")
            
            // Test without token
            print("1️⃣ Testing without authentication...")
            let (_, responseNoAuth) = try await URLSession.shared.data(for: request)
            if let httpResponse = responseNoAuth as? HTTPURLResponse {
                print("   Response: HTTP \(httpResponse.statusCode)")
            }
            
            // Test with token if available
            if let token = SettingsManager.shared.getHuggingFaceToken() {
                print("\n2️⃣ Testing with authentication token...")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                let (data, responseWithAuth) = try await URLSession.shared.data(for: request)
                if let httpResponse = responseWithAuth as? HTTPURLResponse {
                    print("   Response: HTTP \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        print("   ✅ Authentication successful!")
                        
                        // Try to parse model info
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("   Model ID: \(json["id"] ?? "unknown")")
                            print("   Gated: \(json["gated"] ?? "unknown")")
                        }
                    } else if httpResponse.statusCode == 401 {
                        print("   ❌ Authentication failed - invalid token")
                    } else if httpResponse.statusCode == 403 {
                        print("   ❌ Access forbidden - need to accept model license")
                        print("   → Visit: https://huggingface.co/google/gemma-3n-E4B-it")
                    }
                }
            } else {
                print("\n⚠️  No token available for authenticated test")
            }
            
            // Test actual file download
            print("\n3️⃣ Testing file download (config.json)...")
            let fileURL = "https://huggingface.co/google/gemma-3n-E4B-it/resolve/main/config.json"
            var fileRequest = URLRequest(url: URL(string: fileURL)!)
            fileRequest.setValue("Gemi/1.0", forHTTPHeaderField: "User-Agent")
            
            if let token = SettingsManager.shared.getHuggingFaceToken() {
                fileRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (fileData, fileResponse) = try await URLSession.shared.data(for: fileRequest)
            if let httpResponse = fileResponse as? HTTPURLResponse {
                print("   Response: HTTP \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("   ✅ File download successful!")
                    print("   File size: \(fileData.count) bytes")
                    
                    // Check if it's JSON or HTML
                    if let content = String(data: fileData.prefix(100), encoding: .utf8) {
                        if content.contains("<!DOCTYPE") || content.contains("<html") {
                            print("   ⚠️  WARNING: Received HTML instead of JSON!")
                        } else {
                            print("   ✓ Received valid JSON data")
                        }
                    }
                } else {
                    print("   ❌ File download failed")
                    if let errorContent = String(data: fileData, encoding: .utf8) {
                        print("   Error: \(errorContent.prefix(200))...")
                    }
                }
            }
            
        } catch {
            print("❌ Test failed: \(error.localizedDescription)")
        }
        
        print("\n=== End Authentication Test ===\n")
    }
    
    private static func getFileSize(at url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64 {
                return formatBytes(size)
            }
        } catch {
            // Ignore
        }
        return ""
    }
    
    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}