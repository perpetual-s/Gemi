import Foundation

/// Centralized model file specifications with exact sizes from HuggingFace
/// Now using the mlx-community 4-bit quantized model for better performance
enum ModelFileSpecs {
    
    /// Total size of all model files in bytes (mlx-community 4-bit model)
    /// ~5.8 GB total (vs 15.7 GB for original)
    static let totalSize: Int64 = ModelConfiguration.totalSize
    
    /// Individual file specifications with exact sizes
    static let files: [(name: String, size: Int64)] = ModelConfiguration.modelFiles
    
    /// Get only the required files for inference
    static let requiredFiles: [(name: String, size: Int64)] = ModelConfiguration.requiredFiles
    
    /// Calculate total size of required files
    static var requiredFilesTotalSize: Int64 {
        requiredFiles.reduce(0) { $0 + $1.size }
    }
    
    /// File size tolerance for validation (2% or 10KB, whichever is larger)
    static func tolerance(for fileSize: Int64) -> Int64 {
        return max(10_240, Int64(Double(fileSize) * 0.02))
    }
    
    /// Check if a file size is valid
    static func isValidSize(actual: Int64, expected: Int64) -> Bool {
        let tolerance = tolerance(for: expected)
        return abs(actual - expected) <= tolerance
    }
    
    /// Get human-readable file size
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Known issues and their solutions
    static let knownIssues: [String: String] = [
        "model.safetensors.index.json": "This file is often reported as 171KB but actual size varies. We use 171,493 bytes.",
        "tokenizer.json": "Size can vary slightly based on formatting. We allow 2% tolerance.",
        "401 Unauthorized": "Token is invalid or expired. Get a new token from HuggingFace.",
        "403 Forbidden": "Model requires accepting license agreement on HuggingFace website.",
        "Connection timeout": "Large files may timeout on slow connections. Downloads will resume automatically."
    ]
}