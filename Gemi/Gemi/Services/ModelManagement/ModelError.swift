import Foundation

/// Unified error type for model-related operations
enum ModelError: LocalizedError {
    case authenticationRequired
    case downloadFailed(String)
    case verificationFailed(String)
    case modelNotFound
    case invalidConfiguration
    case invalidFormat(String)
    case sizeMismatch(expected: Int64, actual: Int64)
    case hashMismatch(expected: String, actual: String)
    case networkError(Error)
    case fileSystemError(Error)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Authentication required. Please ensure your HuggingFace token is configured."
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .verificationFailed(let reason):
            return "Verification failed: \(reason)"
        case .modelNotFound:
            return "Model not found at expected location"
        case .invalidConfiguration:
            return "Invalid model configuration"
        case .invalidFormat(let reason):
            return "Invalid model format: \(reason)"
        case .sizeMismatch(let expected, let actual):
            return "File size mismatch. Expected: \(expected), Actual: \(actual)"
        case .hashMismatch(let expected, let actual):
            return "File hash mismatch. Expected: \(expected), Actual: \(actual)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .cancelled:
            return "Operation cancelled"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .authenticationRequired:
            return "1. Get a HuggingFace token from https://huggingface.co/settings/tokens\n2. Accept the model license at https://huggingface.co/\(ModelConfiguration.modelID)\n3. Ensure the token has WRITE permissions"
        case .downloadFailed(let reason) where reason.contains("401") || reason.contains("403"):
            return "Check your HuggingFace token and ensure you've accepted the model license"
        case .networkError:
            return "Check your internet connection and try again"
        case .sizeMismatch, .hashMismatch:
            return "Delete the corrupted file and try downloading again"
        default:
            return nil
        }
    }
}