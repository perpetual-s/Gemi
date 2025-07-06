import Foundation

/// Helper for consistent model name handling
enum ModelNameHelper {
    /// Normalize model name to always include :latest suffix
    static func normalize(_ modelName: String) -> String {
        if !modelName.contains(":") {
            return "\(modelName):latest"
        }
        return modelName
    }
    
    /// Get base name without tag
    static func baseName(_ modelName: String) -> String {
        return modelName.split(separator: ":").first.map(String.init) ?? modelName
    }
    
    /// Get all possible variations of a model name
    static func possibleVariations(_ modelName: String) -> [String] {
        let base = baseName(modelName)
        return [
            base,
            "\(base):latest",
            "\(base):*"
        ]
    }
    
    /// Check if two model names refer to the same model
    static func isSameModel(_ name1: String, _ name2: String) -> Bool {
        return baseName(name1) == baseName(name2)
    }
}