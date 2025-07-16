import Foundation
import SwiftUI

/// Comprehensive error recovery system for model operations
@MainActor
struct ModelErrorRecovery {
    
    enum RecoveryAction {
        case retry
        case retryWithAuth
        case clearCacheAndRetry
        case manualDownload
        case contactSupport
        case checkNetwork
        case freeUpSpace
        
        var title: String {
            switch self {
            case .retry:
                return "Retry"
            case .retryWithAuth:
                return "Add Authentication"
            case .clearCacheAndRetry:
                return "Clear Cache & Retry"
            case .manualDownload:
                return "Manual Setup"
            case .contactSupport:
                return "Get Help"
            case .checkNetwork:
                return "Check Connection"
            case .freeUpSpace:
                return "Free Up Space"
            }
        }
        
        var icon: String {
            switch self {
            case .retry:
                return "arrow.clockwise"
            case .retryWithAuth:
                return "key.fill"
            case .clearCacheAndRetry:
                return "trash.circle"
            case .manualDownload:
                return "terminal"
            case .contactSupport:
                return "questionmark.circle"
            case .checkNetwork:
                return "wifi.exclamationmark"
            case .freeUpSpace:
                return "internaldrive"
            }
        }
    }
    
    struct RecoveryOption {
        let action: RecoveryAction
        let description: String
        let handler: () async throws -> Void
    }
    
    /// Analyze error and provide recovery options
    static func recoveryOptions(for error: Error) -> [RecoveryOption] {
        var options: [RecoveryOption] = []
        
        // Handle ModelError cases
        if let modelError = error as? ModelError {
            switch modelError {
            case .authenticationRequired:
                options.append(RecoveryOption(
                    action: .retryWithAuth,
                    description: "Add your HuggingFace token to access Gemma models",
                    handler: {
                        // This will be handled by the UI to show token input
                        throw RecoveryError.requiresUserInput
                    }
                ))
                
            case .downloadFailed(let reason):
                // Network-related failures
                if reason.lowercased().contains("network") || 
                   reason.contains("URLError") ||
                   reason.contains("timeout") {
                    options.append(RecoveryOption(
                        action: .checkNetwork,
                        description: "Check your internet connection and try again",
                        handler: {
                            // Open Network preferences
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    ))
                }
                
                // Space-related failures
                if reason.lowercased().contains("space") || 
                   reason.contains("NSFileWriteOutOfSpaceError") {
                    options.append(RecoveryOption(
                        action: .freeUpSpace,
                        description: "Free up at least 32GB of disk space",
                        handler: {
                            // Open Storage Management
                            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.Storage") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    ))
                }
                
                // Partial download - can resume
                if reason.contains("partial") || reason.contains("incomplete") {
                    options.append(RecoveryOption(
                        action: .retry,
                        description: "Resume the download from where it left off",
                        handler: {
                            try await ModelDownloader().resumeDownload()
                        }
                    ))
                }
                
            case .verificationFailed:
                options.append(RecoveryOption(
                    action: .clearCacheAndRetry,
                    description: "Clear corrupted files and download again",
                    handler: {
                        try await clearModelCache()
                        try await ModelDownloader().startDownload()
                    }
                ))
                
            default:
                break
            }
        }
        
        // Handle NativeChatService errors
        if let chatError = error as? ChatError {
            switch chatError {
            case .modelNotReady:
                options.append(RecoveryOption(
                    action: .retry,
                    description: "Try loading the model again",
                    handler: {
                        try await NativeChatService.shared.loadModel()
                    }
                ))
                
            default:
                break
            }
        }
        
        // Always provide manual setup option
        options.append(RecoveryOption(
            action: .manualDownload,
            description: "Follow manual setup instructions",
            handler: {
                ModelSetupHelper.openManualSetup()
            }
        ))
        
        // Always provide help option
        options.append(RecoveryOption(
            action: .contactSupport,
            description: "View troubleshooting guide",
            handler: {
                if let url = URL(string: "https://github.com/gemi-app/gemi/wiki/troubleshooting") {
                    NSWorkspace.shared.open(url)
                }
            }
        ))
        
        return options
    }
    
    /// Clear model cache for fresh download
    static func clearModelCache() async throws {
        let modelPath = ModelCache.shared.modelPath
        
        // Remove all model files
        if FileManager.default.fileExists(atPath: modelPath.path) {
            try FileManager.default.removeItem(at: modelPath)
        }
        
        // Recreate directory
        try FileManager.default.createDirectory(
            at: modelPath,
            withIntermediateDirectories: true
        )
        
        // Clear any cached state
        try ModelCache.shared.clearCache()
    }
    
    /// Check if error is recoverable
    static func isRecoverable(_ error: Error) -> Bool {
        // Most errors are recoverable except critical system errors
        if let nsError = error as NSError? {
            // Check for unrecoverable system errors
            let unrecoverableCodes = [
                NSFileWriteNoPermissionError,
                NSFileWriteVolumeReadOnlyError
            ]
            
            if unrecoverableCodes.contains(nsError.code) {
                return false
            }
        }
        
        return true
    }
    
    /// Get user-friendly error message
    static func friendlyMessage(for error: Error) -> String {
        if let modelError = error as? ModelError {
            switch modelError {
            case .authenticationRequired:
                return "Gemma models require authentication. Please add your HuggingFace token."
                
            case .downloadFailed(let reason):
                if reason.contains("401") || reason.contains("403") {
                    return "Access denied. Make sure you've accepted the Gemma license agreement."
                } else if reason.contains("network") {
                    return "Network connection issue. Please check your internet connection."
                } else if reason.contains("space") {
                    return "Not enough disk space. Please free up at least 32GB."
                }
                return "Download failed. Please try again."
                
            case .verificationFailed:
                return "Downloaded files appear corrupted. Please try downloading again."
                
            case .modelNotFound:
                return "Model files not found. Please download the model first."
                
            default:
                return modelError.localizedDescription
            }
        }
        
        // Generic error message
        return error.localizedDescription
    }
}

/// Custom error for recovery actions
enum RecoveryError: LocalizedError {
    case requiresUserInput
    case recoveryFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .requiresUserInput:
            return "This action requires user input"
        case .recoveryFailed(let reason):
            return "Recovery failed: \(reason)"
        }
    }
}

/// Recovery UI Component
struct ModelErrorRecoveryView: View {
    let error: Error
    let onDismiss: () -> Void
    let onRetry: () async throws -> Void
    
    @State private var isPerformingAction = false
    @State private var showingTokenInput = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Error icon and title
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("Setup Issue")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(ModelErrorRecovery.friendlyMessage(for: error))
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Recovery options
            VStack(spacing: 12) {
                ForEach(ModelErrorRecovery.recoveryOptions(for: error), id: \.action.title) { option in
                    RecoveryActionButton(
                        option: option,
                        isPerformingAction: $isPerformingAction,
                        showingTokenInput: $showingTokenInput,
                        onRetry: onRetry
                    )
                }
            }
            
            // Dismiss button
            Button("Cancel") {
                onDismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(width: 500)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.Colors.cardBackground)
                .shadow(radius: 20)
        )
        .sheet(isPresented: $showingTokenInput) {
            HuggingFaceTokenView {
                showingTokenInput = false
                Task {
                    try await onRetry()
                }
            }
        }
    }
}

struct RecoveryActionButton: View {
    let option: ModelErrorRecovery.RecoveryOption
    @Binding var isPerformingAction: Bool
    @Binding var showingTokenInput: Bool
    let onRetry: () async throws -> Void
    
    var body: some View {
        Button {
            Task {
                isPerformingAction = true
                defer { isPerformingAction = false }
                
                do {
                    try await option.handler()
                } catch RecoveryError.requiresUserInput {
                    // Handle user input required
                    if option.action == .retryWithAuth {
                        showingTokenInput = true
                    }
                } catch {
                    // Recovery action failed
                    print("Recovery action failed: \(error)")
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: option.action.icon)
                    .font(.system(size: 18))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.action.title)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(option.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isPerformingAction {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isPerformingAction)
    }
}