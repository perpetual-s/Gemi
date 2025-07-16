import Foundation

/// Handles network retries with exponential backoff
struct NetworkRetryHandler {
    
    struct RetryConfiguration {
        let maxAttempts: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let multiplier: Double
        let jitter: Bool
        
        static let `default` = RetryConfiguration(
            maxAttempts: 3,
            initialDelay: 1.0,
            maxDelay: 60.0,
            multiplier: 2.0,
            jitter: true
        )
        
        static let aggressive = RetryConfiguration(
            maxAttempts: 5,
            initialDelay: 0.5,
            maxDelay: 30.0,
            multiplier: 1.5,
            jitter: true
        )
        
        static let conservative = RetryConfiguration(
            maxAttempts: 2,
            initialDelay: 2.0,
            maxDelay: 120.0,
            multiplier: 3.0,
            jitter: false
        )
    }
    
    /// Execute an async operation with retry logic
    static func retry<T>(
        operation: @escaping () async throws -> T,
        configuration: RetryConfiguration = .default,
        shouldRetry: @escaping (Error) -> Bool = isRetriableError
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<configuration.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry this error
                guard shouldRetry(error) else {
                    throw error
                }
                
                // Check if we have more attempts
                guard attempt < configuration.maxAttempts - 1 else {
                    throw RetryError.maxAttemptsReached(
                        attempts: configuration.maxAttempts,
                        lastError: error
                    )
                }
                
                // Calculate delay with exponential backoff
                let delay = calculateDelay(
                    attempt: attempt,
                    configuration: configuration
                )
                
                print("🔄 Retry attempt \(attempt + 1)/\(configuration.maxAttempts) after \(String(format: "%.1f", delay))s delay")
                
                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? RetryError.unknown
    }
    
    /// Calculate delay for exponential backoff
    private static func calculateDelay(
        attempt: Int,
        configuration: RetryConfiguration
    ) -> TimeInterval {
        // Calculate base delay with exponential backoff
        let exponentialDelay = configuration.initialDelay * pow(configuration.multiplier, Double(attempt))
        
        // Cap at maximum delay
        var delay = min(exponentialDelay, configuration.maxDelay)
        
        // Add jitter to prevent thundering herd
        if configuration.jitter {
            let jitterRange = delay * 0.2 // ±20% jitter
            let jitter = Double.random(in: -jitterRange...jitterRange)
            delay += jitter
        }
        
        return max(delay, 0.1) // Minimum 100ms delay
    }
    
    /// Default check for retriable errors
    static func isRetriableError(_ error: Error) -> Bool {
        // Check for common retriable network errors
        if let urlError = error as? URLError {
            let retriableCodes: Set<URLError.Code> = [
                .timedOut,
                .cannotFindHost,
                .cannotConnectToHost,
                .networkConnectionLost,
                .dnsLookupFailed,
                .notConnectedToInternet,
                .dataNotAllowed,
                .internationalRoamingOff
            ]
            return retriableCodes.contains(urlError.code)
        }
        
        // Check for retriable HTTP status codes
        if let httpError = error as? HTTPError {
            let retriableStatusCodes = [408, 429, 500, 502, 503, 504]
            return retriableStatusCodes.contains(httpError.statusCode)
        }
        
        // Check for specific model errors
        if let modelError = error as? ModelError {
            switch modelError {
            case .downloadFailed(let reason):
                // Retry on network-related download failures
                return reason.lowercased().contains("network") ||
                       reason.contains("timeout") ||
                       reason.contains("URLError")
            default:
                return false
            }
        }
        
        return false
    }
    
    /// Check if error is related to authentication
    static func isAuthenticationError(_ error: Error) -> Bool {
        if let modelError = error as? ModelError {
            if case .authenticationRequired = modelError {
                return true
            }
            if case .downloadFailed(let reason) = modelError {
                return reason.contains("401") || reason.contains("403") || reason.contains("Unauthorized")
            }
        }
        
        if let httpError = error as? HTTPError {
            return httpError.statusCode == 401 || httpError.statusCode == 403
        }
        
        return false
    }
}

/// Retry-specific errors
enum RetryError: LocalizedError {
    case maxAttemptsReached(attempts: Int, lastError: Error)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .maxAttemptsReached(let attempts, let lastError):
            return "Failed after \(attempts) attempts. Last error: \(lastError.localizedDescription)"
        case .unknown:
            return "An unknown error occurred during retry"
        }
    }
}

/// HTTP error for status code handling
struct HTTPError: LocalizedError {
    let statusCode: Int
    let message: String?
    
    var errorDescription: String? {
        if let message = message {
            return "HTTP \(statusCode): \(message)"
        }
        return "HTTP error \(statusCode)"
    }
}

/// Retry handler specifically for model downloads
extension NetworkRetryHandler {
    
    /// Retry configuration optimized for large file downloads
    static let downloadConfiguration = RetryConfiguration(
        maxAttempts: 5,
        initialDelay: 2.0,
        maxDelay: 300.0, // 5 minutes max
        multiplier: 2.0,
        jitter: true
    )
    
    /// Download a file with automatic retry and resume support
    static func downloadWithRetry(
        from url: URL,
        to destination: URL,
        headers: [String: String] = [:],
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> URL {
        
        var resumeData: Data?
        
        return try await retry(
            operation: {
                try await performDownload(
                    from: url,
                    to: destination,
                    headers: headers,
                    resumeData: resumeData,
                    progressHandler: progressHandler
                )
            },
            configuration: downloadConfiguration,
            shouldRetry: { error in
                // Save resume data if available
                if let urlError = error as? URLError,
                   let data = urlError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                    resumeData = data
                    return true
                }
                
                return isRetriableError(error)
            }
        )
    }
    
    private static func performDownload(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        resumeData: Data?,
        progressHandler: ((Double) -> Void)?
    ) async throws -> URL {
        
        let session = URLSession(configuration: .default)
        var request = URLRequest(url: url)
        
        // Add headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Create download task
        let (localURL, response): (URL, URLResponse)
        
        if let resumeData = resumeData {
            (localURL, response) = try await session.download(resumeFrom: resumeData)
        } else {
            (localURL, response) = try await session.download(for: request)
        }
        
        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw HTTPError(
                    statusCode: httpResponse.statusCode,
                    message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                )
            }
        }
        
        // Move file to destination
        try FileManager.default.moveItem(at: localURL, to: destination)
        
        return destination
    }
}