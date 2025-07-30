import SwiftUI

/// Error notification banner for chat view
struct ErrorNotificationBanner: View {
    let error: Error
    let onDismiss: () -> Void
    
    @State private var isVisible = true
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                // Error icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                // Error message
                VStack(alignment: .leading, spacing: 2) {
                    Text(errorTitle)
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    if let suggestion = errorSuggestion {
                        Text(suggestion)
                            .font(Theme.Typography.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Dismiss button
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.gradient)
                    .shadow(color: .red.opacity(0.3), radius: 10, y: 5)
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .onAppear {
                // Auto-dismiss after 10 seconds for non-critical errors
                if !isCriticalError {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        withAnimation {
                            isVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }
                }
            }
        }
    }
    
    private var errorTitle: String {
        if let aiError = error as? AIServiceError {
            switch aiError {
            case .serviceUnavailable:
                return "AI Service Unavailable"
            case .connectionFailed:
                return "Connection Failed"
            case .modelLoading:
                return "Model Loading"
            case .invalidResponse:
                return "Invalid Response"
            case .timeout:
                return "Request Timeout"
            }
        } else if let ollamaError = error as? OllamaError {
            switch ollamaError {
            case .notInstalled:
                return "Ollama Not Installed"
            case .notRunning:
                return "Ollama Not Running"
            case .modelNotFound:
                return "Model Not Found"
            case .connectionLostButRecovered:
                return "Connection Restored"
            default:
                return "Ollama Error"
            }
        }
        
        return "Error"
    }
    
    private var errorSuggestion: String? {
        if let aiError = error as? AIServiceError {
            switch aiError {
            case .serviceUnavailable(let message):
                return message.isEmpty ? "Please check if Ollama is running" : message
            case .connectionFailed(let message):
                return message.isEmpty ? "Check your connection and try again" : message
            case .modelLoading(let message):
                return message.isEmpty ? "The AI model is loading" : message
            case .invalidResponse(let message):
                return message.isEmpty ? "Received invalid response from AI" : message
            case .timeout:
                return "The request took too long. Please try again"
            }
        } else if let ollamaError = error as? OllamaError {
            return ollamaError.recoverySuggestion
        }
        
        return error.localizedDescription
    }
    
    private var isCriticalError: Bool {
        if let aiError = error as? AIServiceError {
            switch aiError {
            case .serviceUnavailable, .modelLoading:
                return true
            default:
                return false
            }
        } else if let ollamaError = error as? OllamaError {
            switch ollamaError {
            case .notInstalled, .notRunning:
                return true
            default:
                return false
            }
        }
        
        return false
    }
}

// Preview
struct ErrorNotificationBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ErrorNotificationBanner(
                error: AIServiceError.serviceUnavailable("Ollama is not running"),
                onDismiss: {}
            )
            
            ErrorNotificationBanner(
                error: OllamaError.connectionLostButRecovered,
                onDismiss: {}
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}