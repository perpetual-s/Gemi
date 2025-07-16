import Foundation
import CryptoKit

/// Validates model files after download to ensure they're ready for loading
@MainActor
final class ModelSetupValidator {
    
    // MARK: - File Validation
    
    /// Complete validation of all model files
    static func validateModelFiles(at modelPath: URL) async throws {
        print("\n🔍 Validating model files...")
        
        // Step 1: Check all required files exist
        try validateRequiredFiles(at: modelPath)
        
        // Step 2: Validate file sizes
        try validateFileSizes(at: modelPath)
        
        // Step 3: Validate file contents
        try await validateFileContents(at: modelPath)
        
        // Step 4: Validate config structure
        try validateConfigStructure(at: modelPath)
        
        // Step 5: Validate tokenizer
        try validateTokenizer(at: modelPath)
        
        print("✅ All model files validated successfully!")
    }
    
    /// Check that all required files exist
    private static func validateRequiredFiles(at modelPath: URL) throws {
        let requiredFiles = [
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json"
        ]
        
        // Also need at least one safetensors file
        let safetensorPattern = "model*.safetensors"
        
        for file in requiredFiles {
            let filePath = modelPath.appendingPathComponent(file)
            guard FileManager.default.fileExists(atPath: filePath.path) else {
                throw ValidationError.missingFile(file)
            }
        }
        
        // Check for safetensors files
        let contents = try FileManager.default.contentsOfDirectory(at: modelPath, 
                                                                   includingPropertiesForKeys: nil)
        let safetensorFiles = contents.filter { $0.lastPathComponent.contains("model") && 
                                               $0.pathExtension == "safetensors" }
        
        guard !safetensorFiles.isEmpty else {
            throw ValidationError.missingSafetensors
        }
        
        print("✓ All required files present")
    }
    
    /// Validate file sizes to catch incomplete downloads
    private static func validateFileSizes(at modelPath: URL) throws {
        let minSizes: [String: Int] = [
            "config.json": 500,           // At least 500 bytes
            "tokenizer.json": 1000,       // At least 1KB
            "tokenizer_config.json": 100  // At least 100 bytes
        ]
        
        for (filename, minSize) in minSizes {
            let filePath = modelPath.appendingPathComponent(filename)
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath.path)
            let fileSize = attributes[.size] as? Int ?? 0
            
            guard fileSize >= minSize else {
                throw ValidationError.fileTooSmall(filename, actual: fileSize, expected: minSize)
            }
        }
        
        // Check safetensors files (should be at least 100MB each for Gemma 3n)
        let contents = try FileManager.default.contentsOfDirectory(at: modelPath, 
                                                                   includingPropertiesForKeys: [.fileSizeKey])
        for url in contents where url.pathExtension == "safetensors" {
            let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard fileSize >= 100_000_000 else { // 100MB minimum
                throw ValidationError.safetensorTooSmall(url.lastPathComponent, size: fileSize)
            }
        }
        
        print("✓ All file sizes validated")
    }
    
    /// Validate file contents aren't HTML error pages
    private static func validateFileContents(at modelPath: URL) async throws {
        // Check JSON files aren't HTML
        let jsonFiles = ["config.json", "tokenizer.json", "tokenizer_config.json"]
        
        for filename in jsonFiles {
            let filePath = modelPath.appendingPathComponent(filename)
            let data = try Data(contentsOf: filePath)
            
            // Check if it's HTML
            if let preview = String(data: data.prefix(1000), encoding: .utf8) {
                if preview.contains("<!DOCTYPE") || preview.contains("<html") ||
                   preview.contains("401") || preview.contains("403") ||
                   preview.contains("error") || preview.contains("Error") {
                    throw ValidationError.fileIsHTML(filename, preview: String(preview.prefix(200)))
                }
            }
            
            // Try to parse as JSON
            do {
                _ = try JSONSerialization.jsonObject(with: data)
            } catch {
                throw ValidationError.invalidJSON(filename, error: error)
            }
        }
        
        // Check safetensors files
        let contents = try FileManager.default.contentsOfDirectory(at: modelPath, 
                                                                   includingPropertiesForKeys: nil)
        for url in contents where url.pathExtension == "safetensors" {
            try await validateSafetensorFile(at: url)
        }
        
        print("✓ All file contents validated")
    }
    
    /// Validate individual safetensor file
    private static func validateSafetensorFile(at url: URL) async throws {
        // Read first 1KB to check format
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }
        
        let headerData = try fileHandle.read(upToCount: 1024) ?? Data()
        
        // Check if it's HTML
        if let preview = String(data: headerData, encoding: .utf8) {
            if preview.contains("<!DOCTYPE") || preview.contains("<html") ||
               preview.contains("401") || preview.contains("403") {
                throw ValidationError.safetensorIsHTML(url.lastPathComponent)
            }
        }
        
        // Check safetensor header (first 8 bytes should be header size)
        guard headerData.count >= 8 else {
            throw ValidationError.invalidSafetensorHeader(url.lastPathComponent)
        }
        
        let headerSize = headerData.withUnsafeBytes { bytes in
            bytes.load(as: UInt64.self)
        }
        
        // Sanity check header size
        guard headerSize > 0 && headerSize < 10_000_000 else { // Header shouldn't be > 10MB
            throw ValidationError.invalidSafetensorHeader(url.lastPathComponent)
        }
    }
    
    /// Validate config.json structure
    private static func validateConfigStructure(at modelPath: URL) throws {
        let configPath = modelPath.appendingPathComponent("config.json")
        let data = try Data(contentsOf: configPath)
        
        // Try both nested and flat structures
        var modelType: String?
        var vocabSize: Int?
        
        // First try nested Gemma 3n structure
        if let config = try? JSONDecoder().decode(Gemma3nConfig.self, from: data) {
            modelType = config.modelType
            vocabSize = config.textConfig.vocabSize
        } else if let config = try? JSONDecoder().decode(FlatModelConfig.self, from: data) {
            // Try flat structure
            modelType = config.modelType
            vocabSize = config.vocabSize
        } else {
            // Parse as generic JSON for debugging
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                modelType = json["model_type"] as? String
                vocabSize = json["vocab_size"] as? Int
                
                // Check for nested structure
                if let textConfig = json["text_config"] as? [String: Any] {
                    vocabSize = textConfig["vocab_size"] as? Int ?? vocabSize
                }
            }
        }
        
        // Validate required fields
        guard let type = modelType else {
            throw ValidationError.missingConfigField("model_type")
        }
        
        guard type.contains("gemma") else {
            throw ValidationError.wrongModelType(type, expected: "gemma")
        }
        
        guard vocabSize != nil else {
            throw ValidationError.missingConfigField("vocab_size")
        }
        
        print("✓ Config structure validated (model: \(type))")
    }
    
    /// Validate tokenizer files
    private static func validateTokenizer(at modelPath: URL) throws {
        let tokenizerPath = modelPath.appendingPathComponent("tokenizer.json")
        let data = try Data(contentsOf: tokenizerPath)
        
        // Basic structure check
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ValidationError.invalidTokenizer("Cannot parse tokenizer.json")
        }
        
        // Check for required fields
        let requiredFields = ["model", "added_tokens", "normalizer"]
        for field in requiredFields {
            guard json[field] != nil else {
                throw ValidationError.invalidTokenizer("Missing field: \(field)")
            }
        }
        
        print("✓ Tokenizer validated")
    }
    
    // MARK: - Recovery Helpers
    
    /// Get recovery suggestion for validation error
    static func getRecoverySuggestion(for error: Error) -> String {
        if let validationError = error as? ValidationError {
            switch validationError {
            case .missingFile, .missingSafetensors:
                return """
                    Some model files are missing. This usually happens when:
                    • The download was interrupted
                    • Network issues prevented some files from downloading
                    
                    Please delete the model folder and try downloading again.
                    """
                
            case .fileTooSmall, .safetensorTooSmall:
                return """
                    Some files are incomplete. This can happen when:
                    • The download was interrupted
                    • Disk space ran out during download
                    
                    Please check your available disk space and try downloading again.
                    """
                
            case .fileIsHTML, .safetensorIsHTML:
                return """
                    The downloaded files appear to be error pages instead of model data.
                    This is usually a temporary server issue.
                    
                    Please try again in a few minutes. If the problem persists,
                    the model server may be experiencing issues.
                    """
                
            case .invalidJSON:
                return """
                    Some configuration files are corrupted. This can happen when:
                    • The download was interrupted
                    • Files were partially written
                    
                    Please delete the model folder and download again.
                    """
                
            case .invalidSafetensorHeader:
                return """
                    Model weight files appear to be corrupted. This usually means:
                    • The download was interrupted
                    • Files were not fully written to disk
                    
                    Please delete the model folder and download again.
                    """
                
            case .missingConfigField, .wrongModelType, .invalidTokenizer:
                return """
                    The model configuration is invalid. This might mean:
                    • The wrong model was downloaded
                    • Model files are from different versions
                    
                    Please delete the model folder and ensure you're downloading
                    the correct Gemma 3n model.
                    """
            }
        }
        
        return "An unexpected error occurred. Please try deleting the model folder and downloading again."
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    case missingFile(String)
    case missingSafetensors
    case fileTooSmall(String, actual: Int, expected: Int)
    case safetensorTooSmall(String, size: Int)
    case fileIsHTML(String, preview: String)
    case safetensorIsHTML(String)
    case invalidJSON(String, error: Error)
    case invalidSafetensorHeader(String)
    case missingConfigField(String)
    case wrongModelType(String, expected: String)
    case invalidTokenizer(String)
    
    var errorDescription: String? {
        switch self {
        case .missingFile(let name):
            return "Required file missing: \(name)"
        case .missingSafetensors:
            return "No model weight files found"
        case .fileTooSmall(let name, let actual, let expected):
            return "\(name) is too small (\(actual) bytes, expected at least \(expected))"
        case .safetensorTooSmall(let name, let size):
            return "\(name) is too small (\(size / 1_000_000)MB, expected at least 100MB)"
        case .fileIsHTML(let name, _):
            return "\(name) contains HTML instead of expected data"
        case .safetensorIsHTML(let name):
            return "\(name) contains HTML instead of model weights"
        case .invalidJSON(let name, _):
            return "\(name) contains invalid JSON"
        case .invalidSafetensorHeader(let name):
            return "\(name) has invalid format"
        case .missingConfigField(let field):
            return "Config missing required field: \(field)"
        case .wrongModelType(let actual, let expected):
            return "Wrong model type: \(actual) (expected \(expected))"
        case .invalidTokenizer(let reason):
            return "Invalid tokenizer: \(reason)"
        }
    }
}

// MARK: - Config Structures for Validation

private struct Gemma3nConfig: Codable {
    let modelType: String
    let textConfig: TextConfig
    
    struct TextConfig: Codable {
        let vocabSize: Int
        
        private enum CodingKeys: String, CodingKey {
            case vocabSize = "vocab_size"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case textConfig = "text_config"
    }
}

private struct FlatModelConfig: Codable {
    let modelType: String
    let vocabSize: Int
    
    private enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case vocabSize = "vocab_size"
    }
}