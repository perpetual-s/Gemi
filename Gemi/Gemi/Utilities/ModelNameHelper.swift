//
//  ModelNameHelper.swift
//  Gemi
//
//  Helper utilities for handling Ollama model names consistently
//

import Foundation

/// Helper for normalizing and managing Ollama model names
struct ModelNameHelper {
    
    /// Normalize a model name by ensuring it has a tag (defaults to :latest)
    /// Examples:
    /// - "gemma2:2b" -> "gemma2:2b"
    /// - "nomic-embed-text" -> "nomic-embed-text:latest"
    /// - "gemma3n:latest" -> "gemma3n:latest"
    static func normalize(_ modelName: String) -> String {
        // If the model already has a tag (contains ':'), return as is
        if modelName.contains(":") {
            return modelName
        }
        // Otherwise, append :latest
        return "\(modelName):latest"
    }
    
    /// Get the base name of a model without the tag
    /// Examples:
    /// - "gemma2:2b" -> "gemma2"
    /// - "nomic-embed-text:latest" -> "nomic-embed-text"
    /// - "gemma3n" -> "gemma3n"
    static func baseName(_ modelName: String) -> String {
        if let colonIndex = modelName.firstIndex(of: ":") {
            return String(modelName[..<colonIndex])
        }
        return modelName
    }
    
    /// Get the tag from a model name (returns "latest" if no tag)
    /// Examples:
    /// - "gemma2:2b" -> "2b"
    /// - "nomic-embed-text" -> "latest"
    /// - "gemma3n:latest" -> "latest"
    static func tag(_ modelName: String) -> String {
        if let colonIndex = modelName.firstIndex(of: ":") {
            let tagStart = modelName.index(after: colonIndex)
            return String(modelName[tagStart...])
        }
        return "latest"
    }
    
    /// Check if two model names refer to the same model (considering default :latest tag)
    /// Examples:
    /// - matches("nomic-embed-text", "nomic-embed-text:latest") -> true
    /// - matches("gemma2:2b", "gemma2") -> false
    /// - matches("gemma3n", "gemma3n:latest") -> true
    static func matches(_ modelName1: String, _ modelName2: String) -> Bool {
        return normalize(modelName1) == normalize(modelName2)
    }
    
    /// Check if a model name matches any in a list (considering normalization)
    static func matchesAny(_ modelName: String, in modelList: [String]) -> Bool {
        let normalizedName = normalize(modelName)
        return modelList.contains { matches($0, normalizedName) }
    }
    
    /// Find all variations of a model name that might exist
    /// For example, "nomic-embed-text" returns ["nomic-embed-text", "nomic-embed-text:latest"]
    static func possibleVariations(_ modelName: String) -> [String] {
        let base = baseName(modelName)
        let normalized = normalize(modelName)
        
        var variations = [base, normalized]
        
        // Remove duplicates while preserving order
        var seen = Set<String>()
        return variations.filter { seen.insert($0).inserted }
    }
}

// MARK: - Known Models

extension ModelNameHelper {
    /// Known Gemi models with their normalized names
    struct KnownModels {
        static let mainModel = "gemma3n:latest"
        static let embeddingModel = "nomic-embed-text:latest"
        static let customModel = "gemi-custom:latest"
        
        // Alternative models that are also supported
        static let alternativeMainModel = "gemma2:2b"
        
        /// Check if a model is a known embedding model
        static func isEmbeddingModel(_ modelName: String) -> Bool {
            return ModelNameHelper.matches(modelName, embeddingModel)
        }
        
        /// Check if a model is a known chat model
        static func isChatModel(_ modelName: String) -> Bool {
            return ModelNameHelper.matchesAny(modelName, in: [mainModel, customModel, alternativeMainModel])
        }
    }
}