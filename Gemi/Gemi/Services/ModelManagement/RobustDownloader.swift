import Foundation
import CryptoKit

/// Enhanced downloader with multiple fallback mechanisms
@MainActor
final class RobustDownloader: NSObject, ObservableObject {
    
    // MARK: - Configuration
    
    struct DownloadConfiguration {
        let maxRetries: Int = 5
        let initialRetryDelay: TimeInterval = 2.0
        let maxRetryDelay: TimeInterval = 60.0
        let retryBackoffMultiplier: Double = 2.0
        let chunkSize: Int = 10_485_760 // 10MB chunks for large files
        let connectionTimeout: TimeInterval = 30.0
        let resourceTimeout: TimeInterval = 3600.0 // 1 hour for large files
    }
    
    // MARK: - Download Strategy
    
    enum DownloadStrategy {
        case direct          // Direct download with resume support
        case chunked         // Download in chunks for better reliability
        case fallbackCDN     // Use alternative CDN if available
    }
    
    // MARK: - Properties
    
    private let configuration = DownloadConfiguration()
    private var session: URLSession!
    
    override init() {
        super.init()
        setupSession()
    }
    
    // MARK: - Public Methods
    
    /// Download a file with automatic retry and fallback strategies
    func downloadFile(
        from url: URL,
        to destination: URL,
        expectedSize: Int64,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        
        var lastError: Error?
        var retryCount = 0
        
        while retryCount < configuration.maxRetries {
            do {
                // Try different strategies based on retry count
                let strategy = selectStrategy(for: retryCount)
                
                switch strategy {
                case .direct:
                    return try await directDownload(
                        from: url,
                        to: destination,
                        expectedSize: expectedSize,
                        onProgress: onProgress
                    )
                    
                case .chunked:
                    return try await chunkedDownload(
                        from: url,
                        to: destination,
                        expectedSize: expectedSize,
                        onProgress: onProgress
                    )
                    
                case .fallbackCDN:
                    // Try alternative CDN endpoints
                    if let fallbackURL = getFallbackURL(for: url) {
                        return try await directDownload(
                            from: fallbackURL,
                            to: destination,
                            expectedSize: expectedSize,
                            onProgress: onProgress
                        )
                    } else {
                        throw ModelError.downloadFailed("No fallback CDN available")
                    }
                }
                
            } catch {
                lastError = error
                
                // Don't retry for authentication errors
                if isAuthenticationError(error) {
                    throw error
                }
                
                // Calculate retry delay with exponential backoff
                let delay = min(
                    configuration.initialRetryDelay * pow(configuration.retryBackoffMultiplier, Double(retryCount)),
                    configuration.maxRetryDelay
                )
                
                print("🔄 Download failed (attempt \(retryCount + 1)/\(configuration.maxRetries)). Retrying in \(Int(delay))s...")
                print("   Error: \(error.localizedDescription)")
                
                // Wait before retry
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                retryCount += 1
            }
        }
        
        // All retries exhausted
        throw ModelError.downloadFailed(
            "Download failed after \(configuration.maxRetries) attempts. Last error: \(lastError?.localizedDescription ?? "Unknown error")"
        )
    }
    
    // MARK: - Private Methods
    
    private func setupSession() {
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        config.timeoutIntervalForRequest = configuration.connectionTimeout
        config.timeoutIntervalForResource = configuration.resourceTimeout
        config.httpMaximumConnectionsPerHost = 6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        // Add reliability headers
        config.httpAdditionalHeaders = [
            "User-Agent": "Gemi/1.0 (Robust Downloader)",
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive"
        ]
        
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    private func selectStrategy(for retryCount: Int) -> DownloadStrategy {
        switch retryCount {
        case 0...1:
            return .direct
        case 2...3:
            return .chunked
        default:
            return .fallbackCDN
        }
    }
    
    private func directDownload(
        from url: URL,
        to destination: URL,
        expectedSize: Int64,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        
        // Check for existing partial download
        let partialPath = destination.appendingPathExtension("download")
        let resumeDataPath = destination.appendingPathExtension("resumedata")
        
        var resumeData: Data?
        if FileManager.default.fileExists(atPath: resumeDataPath.path) {
            resumeData = try? Data(contentsOf: resumeDataPath)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let task: URLSessionDownloadTask
            
            if let resumeData = resumeData {
                task = session.downloadTask(withResumeData: resumeData) { [weak self] tempURL, response, error in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.handleDownloadCompletion(
                            tempURL: tempURL,
                            response: response,
                            error: error,
                            destination: destination,
                            expectedSize: expectedSize,
                            continuation: continuation
                        )
                    }
                }
            } else {
                var request = URLRequest(url: url)
                
                // Add range header if partial file exists
                if FileManager.default.fileExists(atPath: partialPath.path),
                   let attributes = try? FileManager.default.attributesOfItem(atPath: partialPath.path),
                   let fileSize = attributes[.size] as? Int64 {
                    request.setValue("bytes=\(fileSize)-", forHTTPHeaderField: "Range")
                }
                
                // Add HuggingFace token if available
                if let token = SettingsManager.shared.getHuggingFaceToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                task = session.downloadTask(with: request) { [weak self] tempURL, response, error in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.handleDownloadCompletion(
                            tempURL: tempURL,
                            response: response,
                            error: error,
                            destination: destination,
                            expectedSize: expectedSize,
                            continuation: continuation
                        )
                    }
                }
            }
            
            // Track progress
            _ = task.progress.observe(\.fractionCompleted) { progress, _ in
                Task { @MainActor in
                    onProgress(progress.fractionCompleted)
                }
            }
            
            task.resume()
        }
    }
    
    private func chunkedDownload(
        from url: URL,
        to destination: URL,
        expectedSize: Int64,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        
        print("📦 Using chunked download strategy for better reliability...")
        
        // Create temporary file for assembly
        let tempPath = destination.appendingPathExtension("chunks")
        
        // Calculate chunks
        let chunkSize = Int64(configuration.chunkSize)
        let chunkCount = (expectedSize + chunkSize - 1) / chunkSize
        
        var downloadedBytes: Int64 = 0
        
        // Download chunks
        for chunkIndex in 0..<Int(chunkCount) {
            let startByte = Int64(chunkIndex) * chunkSize
            let endByte = min(startByte + chunkSize - 1, expectedSize - 1)
            
            var request = URLRequest(url: url)
            request.setValue("bytes=\(startByte)-\(endByte)", forHTTPHeaderField: "Range")
            
            if let token = SettingsManager.shared.getHuggingFaceToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Validate response
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 206 { // 206 = Partial Content
                throw ModelError.downloadFailed("Server doesn't support range requests")
            }
            
            // Append to file
            if chunkIndex == 0 {
                try data.write(to: tempPath)
            } else {
                let fileHandle = try FileHandle(forWritingTo: tempPath)
                defer { try? fileHandle.close() }
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
            }
            
            downloadedBytes += Int64(data.count)
            onProgress(Double(downloadedBytes) / Double(expectedSize))
        }
        
        // Move completed file
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempPath, to: destination)
        
        return destination
    }
    
    private func handleDownloadCompletion(
        tempURL: URL?,
        response: URLResponse?,
        error: Error?,
        destination: URL,
        expectedSize: Int64,
        continuation: CheckedContinuation<URL, Error>
    ) {
        if let error = error {
            // Save resume data if available
            if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                let resumeDataPath = destination.appendingPathExtension("resumedata")
                try? resumeData.write(to: resumeDataPath)
            }
            continuation.resume(throwing: error)
            return
        }
        
        guard let tempURL = tempURL else {
            continuation.resume(throwing: ModelError.downloadFailed("No file received"))
            return
        }
        
        do {
            // Validate downloaded file
            let fileData = try Data(contentsOf: tempURL)
            let actualSize = fileData.count
            
            // Check for size mismatch
            if abs(actualSize - Int(expectedSize)) > max(1024, Int(Double(expectedSize) * 0.01)) {
                throw ModelError.downloadFailed(
                    "File size mismatch. Expected: \(expectedSize) bytes, got: \(actualSize) bytes"
                )
            }
            
            // Move to destination
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: tempURL, to: destination)
            
            // Clean up resume data
            let resumeDataPath = destination.appendingPathExtension("resumedata")
            try? FileManager.default.removeItem(at: resumeDataPath)
            
            continuation.resume(returning: destination)
            
        } catch {
            continuation.resume(throwing: error)
        }
    }
    
    private func getFallbackURL(for url: URL) -> URL? {
        // Try alternative HuggingFace CDN endpoints
        let urlString = url.absoluteString
        
        if urlString.contains("huggingface.co") {
            // Try cdn-lfs.huggingface.co instead of huggingface.co
            let cdnURL = urlString.replacingOccurrences(
                of: "huggingface.co",
                with: "cdn-lfs.huggingface.co"
            )
            return URL(string: cdnURL)
        }
        
        return nil
    }
    
    private func isAuthenticationError(_ error: Error) -> Bool {
        if let modelError = error as? ModelError {
            switch modelError {
            case .authenticationRequired:
                return true
            case .downloadFailed(let reason):
                return reason.contains("401") || reason.contains("403") || 
                       reason.lowercased().contains("auth")
            default:
                return false
            }
        }
        return false
    }
}

// MARK: - URLSessionDownloadDelegate

extension RobustDownloader: URLSessionDownloadDelegate {
    
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // Progress is handled by Progress observation
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Handled in completion handler
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // Handled in completion handler
    }
}