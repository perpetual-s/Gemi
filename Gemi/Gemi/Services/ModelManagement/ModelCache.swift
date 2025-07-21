import Foundation

/// Manages local storage and caching of model files
@MainActor
final class ModelCache {
    static let shared = ModelCache()
    
    // MARK: - Properties
    
    /// Root directory for all Gemi data
    var applicationSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("perpetual-s-Inc.Gemi", isDirectory: true)
    }
    
    /// Directory for model files
    var modelsDirectory: URL {
        applicationSupportURL.appendingPathComponent("Models", isDirectory: true)
    }
    
    /// Path to the Gemma 3n model
    var modelPath: URL {
        // For development: Use direct path to model in source directory
        #if DEBUG
        let projectPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // Remove ModelCache.swift
            .deletingLastPathComponent()  // Remove ModelManagement
            .deletingLastPathComponent()  // Remove Services
            .deletingLastPathComponent()  // Remove Gemi
            .appendingPathComponent("Models")
            .appendingPathComponent("mlx-gemma-3n-E4B-it-4bit")
        
        if FileManager.default.fileExists(atPath: projectPath.path) {
            print("🔧 DEBUG: Using model from source directory: \(projectPath.path)")
            return projectPath
        }
        #endif
        
        // Production: Check if model is bundled with the app
        if let bundledModelPath = Bundle.main.path(forResource: "mlx-gemma-3n-E4B-it-4bit", ofType: nil, inDirectory: "Models") {
            return URL(fileURLWithPath: bundledModelPath)
        }
        
        // Fallback to Application Support for downloaded models
        return modelsDirectory.appendingPathComponent("gemma-3n-e4b-it", isDirectory: true)
    }
    
    /// Cache directory for temporary files
    var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("perpetual-s-Inc.Gemi", isDirectory: true)
    }
    
    // MARK: - Initialization
    
    private init() {
        setupDirectories()
    }
    
    // MARK: - Public Methods
    
    /// Check if the model is completely downloaded
    func isModelComplete() async -> Bool {
        let requiredFiles = [
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "model.safetensors.index.json",
            "model-00001-of-00002.safetensors",
            "model-00002-of-00002.safetensors"
        ]
        
        // Check if we're using a bundled model
        let isBundled = modelPath.path.contains(Bundle.main.bundlePath)
        
        for file in requiredFiles {
            let filePath = modelPath.appendingPathComponent(file)
            if !FileManager.default.fileExists(atPath: filePath.path) {
                // For bundled models, log the missing file for debugging
                if isBundled {
                    print("⚠️ Bundled model missing file: \(file)")
                }
                return false
            }
        }
        
        if isBundled {
            print("✅ Using bundled model at: \(modelPath.path)")
        }
        
        return true
    }
    
    /// Get the size of downloaded model files
    func getModelSize() -> Int64 {
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            return 0
        }
        
        do {
            let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isDirectoryKey]
            let enumerator = FileManager.default.enumerator(
                at: modelPath,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )!
            
            var totalSize: Int64 = 0
            
            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                if resourceValues.isDirectory == false {
                    totalSize += Int64(resourceValues.totalFileAllocatedSize ?? 0)
                }
            }
            
            return totalSize
        } catch {
            print("Error calculating model size: \(error)")
            return 0
        }
    }
    
    /// Clear all cached models
    func clearCache() throws {
        // Only clear models in Application Support, never bundled models
        let isBundled = modelPath.path.contains(Bundle.main.bundlePath)
        if isBundled {
            print("⚠️ Cannot clear bundled model cache")
            return
        }
        
        if FileManager.default.fileExists(atPath: modelsDirectory.path) {
            try FileManager.default.removeItem(at: modelsDirectory)
        }
        setupDirectories()
    }
    
    /// Clean up partial downloads (resume data files)
    func cleanupPartialDownloads() {
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: modelPath, includingPropertiesForKeys: nil)
            
            // Remove .download files (resume data)
            for url in contents {
                if url.pathExtension == "download" {
                    try? fileManager.removeItem(at: url)
                    print("🧹 Cleaned up partial download: \(url.lastPathComponent)")
                }
            }
        } catch {
            // Directory might not exist yet
        }
    }
    
    /// Clear temporary cache files
    func clearTemporaryCache() throws {
        if FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try FileManager.default.removeItem(at: cacheDirectory)
        }
        setupDirectories()
    }
    
    /// Get available disk space
    func getAvailableDiskSpace() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(
                forPath: NSHomeDirectory()
            )
            
            if let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                return freeSpace.int64Value
            }
        } catch {
            print("Error getting disk space: \(error)")
        }
        
        return 0
    }
    
    /// Check if there's enough space for the model
    func hasEnoughSpace() -> Bool {
        let requiredSpace: Int64 = 10 * 1024 * 1024 * 1024 // 10GB minimum
        return getAvailableDiskSpace() > requiredSpace
    }
    
    // MARK: - Private Methods
    
    private func setupDirectories() {
        do {
            // Create Application Support directory
            try FileManager.default.createDirectory(
                at: applicationSupportURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Create Models directory
            try FileManager.default.createDirectory(
                at: modelsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Only create model-specific directory if not using bundled model
            let isBundled = modelPath.path.contains(Bundle.main.bundlePath)
            if !isBundled {
                try FileManager.default.createDirectory(
                    at: modelPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            
            // Create Cache directory
            try FileManager.default.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Exclude from backup
            var modelsResourceValues = URLResourceValues()
            modelsResourceValues.isExcludedFromBackup = true
            var modelsDir = modelsDirectory
            try modelsDir.setResourceValues(modelsResourceValues)
            
            var cacheResourceValues = URLResourceValues()
            cacheResourceValues.isExcludedFromBackup = true
            var cacheDir = cacheDirectory
            try cacheDir.setResourceValues(cacheResourceValues)
            
        } catch {
            print("Error setting up directories: \(error)")
        }
    }
    
    /// Get metadata for a model file
    func getFileMetadata(for filename: String) -> [String: Any]? {
        let filePath = modelPath.appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return nil
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath.path)
            
            return [
                "size": attributes[.size] ?? 0,
                "modificationDate": attributes[.modificationDate] ?? Date(),
                "creationDate": attributes[.creationDate] ?? Date()
            ]
        } catch {
            print("Error getting file metadata: \(error)")
            return nil
        }
    }
}