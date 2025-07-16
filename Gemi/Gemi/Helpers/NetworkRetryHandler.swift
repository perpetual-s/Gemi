import Foundation

/// Handles network retries with exponential backoff for robust downloads
@MainActor
final class NetworkRetryHandler {
    
    struct RetryConfiguration {
        let maxRetries: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let backoffMultiplier: Double
        
        static let `default` = RetryConfiguration(
            maxRetries: 3,
            initialDelay: 2.0,
            maxDelay: 30.0,
            backoffMultiplier: 2.0
        )
        
        static let aggressive = RetryConfiguration(
            maxRetries: 5,
            initialDelay: 1.0,
            maxDelay: 60.0,
            backoffMultiplier: 1.5
        )
    }
    
    /// Execute an async operation with automatic retry on failure
    static func withRetry<T: Sendable>(
        operation: @escaping () async throws -> T,
        configuration: RetryConfiguration = .default,
        shouldRetry: @escaping (Error) -> Bool = { _ in true },
        onRetry: @escaping (Int, Error) -> Void = { _, _ in }
    ) async throws -> T {
        
        var lastError: Error?
        var currentDelay = configuration.initialDelay
        
        for attempt in 0..<configuration.maxRetries {
            do {
                // Try the operation
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry this error
                guard shouldRetry(error) else {
                    throw error
                }
                
                // Check if we have more retries
                guard attempt < configuration.maxRetries - 1 else {
                    throw error
                }
                
                // Notify about retry
                onRetry(attempt + 1, error)
                
                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                
                // Calculate next delay with exponential backoff
                currentDelay = min(
                    currentDelay * configuration.backoffMultiplier,
                    configuration.maxDelay
                )
            }
        }
        
        // This should never happen, but throw last error if it does
        throw lastError ?? URLError(.unknown)
    }
    
    /// Determine if an error is retryable
    static func isRetryableError(_ error: Error) -> Bool {
        // Network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .dataNotAllowed:
                return true
            default:
                return false
            }
        }
        
        // HTTP errors
        if let modelError = error as? ModelError {
            switch modelError {
            case .downloadFailed(let reason):
                // Retry on temporary server errors
                if reason.contains("500") || reason.contains("502") || 
                   reason.contains("503") || reason.contains("504") {
                    return true
                }
                // Don't retry auth errors
                if reason.contains("401") || reason.contains("403") {
                    return false
                }
                return true
            default:
                return false
            }
        }
        
        // NSURLError domain errors
        if (error as NSError).domain == NSURLErrorDomain {
            let code = (error as NSError).code
            switch code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorNotConnectedToInternet:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    /// Create a user-friendly message for retry attempts
    static func retryMessage(for attempt: Int, error: Error) -> String {
        let errorType: String
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                errorType = "Connection timed out"
            case .cannotConnectToHost, .cannotFindHost:
                errorType = "Cannot connect to server"
            case .networkConnectionLost:
                errorType = "Network connection lost"
            case .notConnectedToInternet:
                errorType = "No internet connection"
            default:
                errorType = "Network error"
            }
        } else {
            errorType = "Download error"
        }
        
        return "\(errorType). Retrying... (Attempt \(attempt + 1))"
    }
}