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
        ("config.json", 270_336),                      // Model configuration ~264 kB
        ("generation_config.json", 215),               // Generation settings
        ("preprocessor_config.json", 298),             // Preprocessor config
        ("processor_config.json", 292),                // Processor config
        ("special_tokens_map.json", 769),              // Special tokens
        ("tokenizer.json", 33_442_553),               // Tokenizer ~31.9 MB
        ("tokenizer.model", 4_696_020),               // Tokenizer model ~4.5 MB
        ("tokenizer_config.json", 1_228_800),         // Tokenizer config ~1.2 MB
        
        // Model weight files (4-bit quantized)
        ("model.safetensors.index.json", 175_104),    // Index file ~171 kB
        ("model-00001-of-00002.safetensors", 5_364_004_911),  // ~5.0 GB
        ("model-00002-of-00002.safetensors", 455_053_642),    // ~434 MB
    ]
    
    /// Required files for inference (subset of all files)
    static let requiredFiles: [(name: String, size: Int64)] = [
        ("config.json", 270_336),
        ("tokenizer.json", 33_442_553),
        ("tokenizer_config.json", 1_228_800),
        ("model.safetensors.index.json", 175_104),
        ("model-00001-of-00002.safetensors", 5_364_004_911),
        ("model-00002-of-00002.safetensors", 455_053_642),
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