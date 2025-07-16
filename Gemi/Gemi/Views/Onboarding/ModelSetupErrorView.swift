import SwiftUI

/// Beautiful error view for model setup failures with actionable recovery options
struct ModelSetupErrorView: View {
    let error: Error
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    @State private var showingDetails = false
    @State private var isRetrying = false
    
    private var errorInfo: (title: String, message: String, suggestion: String) {
        // Extract user-friendly error information
        if let setupError = error as? ModelSetupService.SetupError {
            return (
                title: "Setup Issue",
                message: setupError.userFriendlyMessage,
                suggestion: setupError.recoverySuggestion ?? "Please try again"
            )
        } else if let modelError = error as? ModelError {
            switch modelError {
            case .downloadFailed(let reason):
                return (
                    title: "Download Issue",
                    message: cleanupErrorMessage(reason),
                    suggestion: "Check your internet connection and try again"
                )
            case .modelNotFound:
                return (
                    title: "Model Not Found",
                    message: "The AI model files are missing",
                    suggestion: "Click retry to download the model"
                )
            case .invalidFormat(let reason):
                return (
                    title: "Setup Issue",
                    message: cleanupErrorMessage(reason),
                    suggestion: "Delete the model folder and try again"
                )
            default:
                return (
                    title: "Setup Issue",
                    message: "Something went wrong during setup",
                    suggestion: "Please try again or restart the app"
                )
            }
        } else {
            return (
                title: "Unexpected Issue",
                message: "An unexpected error occurred",
                suggestion: "Please try again or restart Gemi"
            )
        }
    }
    
    private func cleanupErrorMessage(_ message: String) -> String {
        // Remove technical jargon and make message user-friendly
        return message
            .replacingOccurrences(of: "HTTP", with: "Connection")
            .replacingOccurrences(of: "401", with: "error")
            .replacingOccurrences(of: "403", with: "error")
            .replacingOccurrences(of: "authentication", with: "connection")
            .replacingOccurrences(of: "Authentication", with: "Connection")
            .replacingOccurrences(of: "safetensors", with: "model file")
            .replacingOccurrences(of: "Safetensors", with: "Model file")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            ZStack {
                LinearGradient(
                    colors: [Color.red.opacity(0.1), Color.red.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
                
                VStack(spacing: 16) {
                    // Error icon with animation
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                            .symbolEffect(.pulse)
                    }
                    
                    Text(errorInfo.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            
            // Content
            VStack(spacing: 24) {
                // Error message
                Text(errorInfo.message)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
                
                // Suggestion box
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    
                    Text(errorInfo.suggestion)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 40)
                
                // Detailed error (collapsible)
                if showingDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Technical Details")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text(error.localizedDescription)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.05))
                            )
                    }
                    .padding(.horizontal, 40)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    // Retry button
                    Button(action: {
                        isRetrying = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onRetry()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isRetrying {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            
                            Text(isRetrying ? "Retrying..." : "Try Again")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isRetrying)
                    
                    HStack(spacing: 16) {
                        // Show details button
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                showingDetails.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                Text(showingDetails ? "Hide Details" : "Show Details")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        // Cancel button
                        Button(action: onDismiss) {
                            Text("Cancel")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            .padding(.vertical, 32)
            
            Spacer()
            
            // Help footer
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 12))
                Text("If this continues, try restarting Gemi")
                    .font(.system(size: 12))
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 24)
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Preview

struct ModelSetupErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ModelSetupErrorView(
                error: ModelError.downloadFailed("Connection error. Please check your internet."),
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Download Error")
            
            ModelSetupErrorView(
                error: ModelError.invalidFormat("Model file appears corrupted"),
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Format Error")
        }
    }
}