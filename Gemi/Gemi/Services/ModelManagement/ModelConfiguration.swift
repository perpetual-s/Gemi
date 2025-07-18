import Foundation

/// Central configuration for the AI model
/// This is the single source of truth for model selection
enum ModelConfiguration {
    
    // MARK: - Model Selection
    
    /// The model we're using - mlx-community version is 63% smaller and pre-optimized
    static let modelID = "mlx-community/gemma-3n-E4B-it-4bit"
    
    /// Base URL for downloading model files
    static var baseURL: String {
        "https://huggingface.co/\(modelID)/resolve/main/"
    }
    
    /// CDN URL for faster downloads
    static var cdnURL: String {
        "https://cdn-lfs.huggingface.co/\(modelID)/"
    }
    
    /// Model display name for UI
    static let displayName = "Gemma 3n E4B (4-bit MLX)"
    
    /// Original Google model for reference
    static let originalModelID = "google/gemma-3n-E4B-it"
    
    // MARK: - Model Files
    
    /// Files for the mlx-community 4-bit model
    /// These are the actual files from the HuggingFace repo
    static let modelFiles: [(name: String, size: Int64)] = [
        // Configuration files
        ("config.json", 4_596),                        // Model configuration
        ("generation_config.json", 215),               // Generation settings
        ("preprocessor_config.json", 1_150),           // Preprocessor config
        ("processor_config.json", 90),                 // Processor config
        ("special_tokens_map.json", 760),              // Special tokens
        ("tokenizer.json", 35_026_124),               // Tokenizer ~33.4 MB
        ("tokenizer.model", 4_240_000),               // Tokenizer model (approx)
        ("tokenizer_config.json", 1_258_291),         // Tokenizer config
        
        // Model weight files (4-bit quantized)
        ("model.safetensors.index.json", 16_956),     // Index file for 2-part model
        ("model-00001-of-00002.safetensors", 3_118_465_088),  // ~2.9 GB
        ("model-00002-of-00002.safetensors", 3_029_598_816),  // ~2.8 GB
    ]
    
    /// Required files for inference (subset of all files)
    static let requiredFiles: [(name: String, size: Int64)] = [
        ("config.json", 4_596),
        ("tokenizer.json", 35_026_124),
        ("tokenizer_config.json", 1_258_291),
        ("model.safetensors.index.json", 16_956),
        ("model-00001-of-00002.safetensors", 3_118_465_088),
        ("model-00002-of-00002.safetensors", 3_029_598_816),
    ]
    
    /// Total size of all required files
    static var totalSize: Int64 {
        requiredFiles.reduce(0) { $0 + $1.size }
    }
    
    /// Human-readable total size
    static var totalSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    // MARK: - Validation
    
    /// File size tolerance for validation (2% or 10KB, whichever is larger)
    static func tolerance(for fileSize: Int64) -> Int64 {
        return max(10_240, Int64(Double(fileSize) * 0.02))
    }
    
    /// Check if a file size is valid
    static func isValidSize(actual: Int64, expected: Int64) -> Bool {
        let tolerance = tolerance(for: expected)
        return abs(actual - expected) <= tolerance
    }
}