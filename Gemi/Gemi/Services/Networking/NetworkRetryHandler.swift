import Foundation

/// Handles network retry logic with exponential backoff
enum NetworkRetryHandler {
    
    struct Configuration {
        let maxAttempts: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let backoffMultiplier: Double
        
        static let standard = Configuration(
            maxAttempts: 3,
            initialDelay: 1.0,
            maxDelay: 30.0,
            backoffMultiplier: 2.0
        )
        
        static let aggressive = Configuration(
            maxAttempts: 5,
            initialDelay: 2.0,
            maxDelay: 60.0,
            backoffMultiplier: 1.5
        )
    }
    
    /// Perform an async operation with retry logic
    static func withRetry<T>(
        operation: @escaping () async throws -> T,
        configuration: Configuration = .standard,
        shouldRetry: ((Error) -> Bool)? = nil,
        onRetry: ((Int, Error) -> Void)? = nil
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<configuration.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry
                let shouldRetryError = shouldRetry?(error) ?? isRetryableError(error)
                
                if !shouldRetryError || attempt == configuration.maxAttempts - 1 {
                    throw error
                }
                
                // Calculate delay with exponential backoff
                let delay = min(
                    configuration.initialDelay * pow(configuration.backoffMultiplier, Double(attempt)),
                    configuration.maxDelay
                )
                
                // Notify about retry
                onRetry?(attempt + 1, error)
                
                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? URLError(.unknown)
    }
    
    /// Determine if an error is retryable
    static func isRetryableError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .dataNotAllowed,
                 .internationalRoamingOff:
                return true
            default:
                return false
            }
        }
        
        // Check for specific HTTP status codes
        if let httpError = error as? ModelError,
           case .downloadFailed(let reason) = httpError {
            // Don't retry authentication errors
            if reason.contains("401") || reason.contains("403") {
                return false
            }
            // Retry server errors
            if reason.contains("500") || reason.contains("502") || 
               reason.contains("503") || reason.contains("504") {
                return true
            }
        }
        
        // Default to not retrying unknown errors
        return false
    }
    
    /// Get a user-friendly retry message
    static func retryMessage(for attempt: Int, error: Error) -> String {
        let errorDescription = if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                "Connection timed out"
            case .cannotFindHost:
                "Cannot find server"
            case .cannotConnectToHost:
                "Cannot connect to server"
            case .networkConnectionLost:
                "Network connection lost"
            case .notConnectedToInternet:
                "No internet connection"
            default:
                "Network error"
            }
        } else {
            "Download error"
        }
        
        return "Retry attempt \(attempt): \(errorDescription)"
    }
}