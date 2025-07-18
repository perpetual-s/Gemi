import Foundation
import AppKit
import SwiftUI

/// Helper for Gemma 3n model setup and debugging
struct ModelSetupHelper {
    
    /// Open documentation about model setup
    @MainActor
    static func openManualSetup() {
        // Show the manual setup window
        let manualSetupView = ManualSetupView()
        let hostingController = NSHostingController(rootView: manualSetupView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Manual Model Setup"
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Keep window reference to prevent deallocation
        NSApp.activate(ignoringOtherApps: true)
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
                
            case .authenticationRequired:
                return """
                Authentication required.
                
                For mlx-community models: No token needed!
                For other models: Please add your HuggingFace token.
                """
                
            case .modelNotLoaded:
                return """
                Model not loaded.
                
                The model needs to be loaded into memory before use.
                
                Please wait for the model to load completely.
                """
                
            case .invalidConfiguration:
                return """
                Invalid model configuration.
                
                The model configuration file may be corrupted.
                
                Please delete the model folder and download again.
                """
                
            case .invalidFormat(let reason):
                return """
                Invalid model format: \(reason)
                
                The model files may be corrupted or incomplete.
                
                Please delete the model folder and download again.
                """
                
            case .sizeMismatch, .hashMismatch, .networkError, .fileSystemError, .cancelled:
                return """
                An error occurred: \(modelError.localizedDescription)
                
                Please try again or restart the app.
                """
            }
        }
        
        return """
        An unexpected error occurred: \(error.localizedDescription)
        
        Please try restarting Gemi and trying again.
        """
    }
}