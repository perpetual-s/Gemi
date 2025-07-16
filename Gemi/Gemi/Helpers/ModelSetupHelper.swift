import Foundation
import AppKit

/// Helper for Gemma 3n model setup and debugging
struct ModelSetupHelper {
    
    /// Open documentation about model setup
    static func openManualSetup() {
        // Since the model downloads automatically, just open the GitHub docs
        if let url = URL(string: "https://github.com/gemi-app/gemi#setup") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Check if model directory exists
    @MainActor
    static func checkModelDirectory() -> Bool {
        return FileManager.default.fileExists(atPath: ModelCache.shared.modelPath.path)
    }
    
    /// Get helpful error message based on the issue
    static func getSetupErrorMessage(for error: Error) -> String {
        if let modelError = error as? ModelError {
            switch modelError {
            case .modelNotFound:
                return """
                Gemma 3n model not found.
                
                The model will be downloaded automatically (~8GB).
                
                Please ensure you have a stable internet connection.
                """
                
            case .downloadFailed(let reason):
                return """
                Failed to download the model: \(reason)
                
                Please check your internet connection and try again.
                
                The download will resume from where it left off.
                """
                
            case .verificationFailed(let file):
                return """
                Model file verification failed: \(file)
                
                The file may be corrupted. It will be re-downloaded automatically.
                
                Please try again.
                """
                
            case .extractionFailed(let reason):
                return """
                Failed to extract model: \(reason)
                
                Please ensure you have enough disk space (20GB recommended).
                """
                
            case .authenticationRequired(let message):
                return message
            }
        }
        
        return """
        An unexpected error occurred: \(error.localizedDescription)
        
        Please try restarting Gemi and trying again.
        """
    }
}