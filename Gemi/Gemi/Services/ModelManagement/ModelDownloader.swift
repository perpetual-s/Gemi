import Foundation
import Combine
import CryptoKit
import CryptoKit

/// Handles downloading of Gemma 3n model files from HuggingFace
@MainActor
final class ModelDownloader: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var downloadState: DownloadState = .notStarted
    @Published var progress: Double = 0.0
    @Published var currentFile: String = ""
    @Published var error: Error?
    @Published var bytesDownloaded: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var downloadStartTime: Date?
    @Published var downloadSpeed: Double = 0 // bytes per second
    
    // MARK: - Types
    
    enum DownloadState: Equatable {
        case notStarted
        case preparing
        case downloading(file: String, progress: Double)
        case verifying
        case extracting
        case completed
        case failed(String)
        case cancelled
        
        var isDownloading: Bool {
            if case .downloading = self { return true }
            return false
        }
    }
    
    struct ModelFile {
        let name: String
        let url: String
        let size: Int64
        var sha256: String
    }
    
    // MARK: - Properties
    
    private let modelID = "google/gemma-3n-E4B-it"
    private let baseURL = "https://huggingface.co/google/gemma-3n-E4B-it/resolve/main/"
    
    // Required model files for Gemma 3n E4B
    // Exact sizes from HuggingFace API as of 2025-07-18
    private var requiredFiles: [ModelFile] = [
        ModelFile(name: "config.json", 
                 url: "config.json",
                 size: 4_596,  // 4.54 KB from HF
                 sha256: "placeholder_hash_config"),
        ModelFile(name: "tokenizer.json",
                 url: "tokenizer.json", 
                 size: 35_026_124,  // 33.4 MB from HF
                 sha256: "placeholder_hash_tokenizer"),
        ModelFile(name: "tokenizer_config.json",
                 url: "tokenizer_config.json",
                 size: 1_258_291,  // 1.2 MB from HF
                 sha256: "placeholder_hash_tokenizer_config"),
        ModelFile(name: "model.safetensors.index.json",
                 url: "model.safetensors.index.json",
                 size: 171_423,  // 167.4 KB - actual size from HF API
                 sha256: "placeholder_hash_index"),
        ModelFile(name: "model-00001-of-00004.safetensors",
                 url: "model-00001-of-00004.safetensors",
                 size: 3_077_103_824,  // 2.87 GB - actual size from HF API
                 sha256: "placeholder_hash_model1"),
        ModelFile(name: "model-00002-of-00004.safetensors",
                 url: "model-00002-of-00004.safetensors",
                 size: 4_966_792_808,  // 4.63 GB - actual size from HF API
                 sha256: "placeholder_hash_model2"),
        ModelFile(name: "model-00003-of-00004.safetensors",
                 url: "model-00003-of-00004.safetensors",
                 size: 4_992_870_216,  // 4.65 GB - actual size from HF API
                 sha256: "placeholder_hash_model3"),
        ModelFile(name: "model-00004-of-00004.safetensors",
                 url: "model-00004-of-00004.safetensors",
                 size: 2_663_414_864,  // 2.48 GB - actual size from HF API
                 sha256: "placeholder_hash_model4")
    ]
    
    private var downloadTasks: [URLSessionDownloadTask] = []
    private var session: URLSession!
    private let modelCache = ModelCache.shared
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupURLSession()
        calculateTotalSize()
        // Ensure totalBytes is published immediately
        self.totalBytes = requiredFiles.reduce(0) { $0 + $1.size }
    }
    
    // MARK: - Public Methods
    
    /// Start downloading the model
    func startDownload() async throws {
        guard downloadState == .notStarted || downloadState == .failed("") || downloadState == .cancelled else {
            return
        }
        
        downloadState = .preparing
        currentFile = "Preparing download..."
        downloadStartTime = Date()
        bytesDownloaded = 0
        
        // Check if model already exists
        if await modelCache.isModelComplete() {
            downloadState = .completed
            progress = 1.0
            return
        }
        
        // Fetch file metadata from HuggingFace API for SHA-256 hashes
        await fetchAndUpdateFileHashes()
        
        // CRITICAL: Check authentication BEFORE downloading
        // This prevents users from waiting 20 minutes only to fail
        do {
            try await verifyHuggingFaceAccess()
        } catch {
            self.error = error
            downloadState = .failed(error.localizedDescription)
            throw error
        }
        
        // Start downloading missing files
        do {
            try await downloadMissingFiles()
        } catch {
            self.error = error
            downloadState = .failed(error.localizedDescription)
            throw error
        }
    }
    
    /// Cancel all ongoing downloads
    func cancelDownload() {
        downloadTasks.forEach { $0.cancel() }
        downloadTasks.removeAll()
        downloadState = .cancelled
        progress = 0.0
    }
    
    /// Resume a paused download
    func resumeDownload() async throws {
        if case .failed = downloadState {
            // Clean up any partial downloads before retrying
            modelCache.cleanupPartialDownloads()
            try await startDownload()
        } else if case .cancelled = downloadState {
            try await startDownload()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupURLSession() {
        let configuration = URLSessionConfiguration.default
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForResource = 3600 // 1 hour timeout
        configuration.httpMaximumConnectionsPerHost = 4 // Parallel downloads
        
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    /// Verify HuggingFace authentication BEFORE downloading
    /// This prevents users from waiting 20 minutes only to fail
    private func verifyHuggingFaceAccess() async throws {
        // We always have a token now - embedded for zero friction
        guard let token = SettingsManager.shared.getHuggingFaceToken() else {
            // This should never happen with embedded token
            print("❌ CRITICAL: No HuggingFace token found!")
            print("   - Check if .env file exists in app bundle")
            print("   - Verify DMG was created with create-dmg.sh script")
            throw ModelError.downloadFailed("Configuration error: No authentication token found")
        }
        
        // Test access to a small file to verify authentication
        let testURL = URL(string: baseURL + "config.json")!
        var request = URLRequest(url: testURL)
        request.httpMethod = "HEAD" // Just check headers, don't download
        request.setValue("Gemi/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    // Success - authentication working
                    print("✅ HuggingFace authentication verified")
                    return
                case 401:
                    throw ModelError.downloadFailed("Authentication failed. The model access may have changed. Please contact support.")
                case 403:
                    throw ModelError.downloadFailed("Model access forbidden. The model permissions may have changed. Please contact support.")
                default:
                    throw ModelError.downloadFailed("Authentication check failed: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch let error as ModelError {
            throw error
        } catch {
            // Network error - let download attempt proceed
            // (might be temporary network issue)
            print("⚠️ Could not verify authentication: \(error.localizedDescription)")
        }
    }
    
    private func calculateTotalSize() {
        totalBytes = requiredFiles.reduce(0) { $0 + $1.size }
    }
    
    private func downloadMissingFiles() async throws {
        var filesToDownload: [ModelFile] = []
        
        // Check which files need downloading
        for file in requiredFiles {
            let localPath = modelCache.modelPath.appendingPathComponent(file.name)
            
            if FileManager.default.fileExists(atPath: localPath.path) {
                // Verify existing file
                if try await verifyFile(at: localPath, expectedHash: file.sha256) {
                    bytesDownloaded += file.size
                    // Update progress immediately for existing files
                    updateOverallProgress()
                    continue
                }
            }
            
            filesToDownload.append(file)
        }
        
        if filesToDownload.isEmpty {
            downloadState = .completed
            progress = 1.0
            return
        }
        
        // Download files in parallel (up to 4 at a time) with retry
        downloadState = .downloading(file: "Starting downloads...", progress: 0.0)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for file in filesToDownload {
                group.addTask {
                    // Use NetworkRetryHandler for robust downloads
                    try await NetworkRetryHandler.withRetry(
                        operation: {
                            try await self.downloadFile(file)
                        },
                        configuration: .aggressive,
                        shouldRetry: { error in
                            // Don't retry auth errors
                            if let modelError = error as? ModelError {
                                switch modelError {
                                case .authenticationRequired:
                                    return false
                                case .downloadFailed(let reason) where reason.contains("401") || reason.contains("403"):
                                    return false
                                default:
                                    return true
                                }
                            }
                            return NetworkRetryHandler.isRetryableError(error)
                        },
                        onRetry: { attempt, error in
                            let message = NetworkRetryHandler.retryMessage(for: attempt, error: error)
                            Task { @MainActor in
                                self.currentFile = message
                            }
                            print("🔄 \(message) for \(file.name)")
                        }
                    )
                }
            }
            
            try await group.waitForAll()
        }
        
        // Verify all files after download
        downloadState = .verifying
        try await verifyAllFiles()
        
        // Validate the complete model setup
        print("\n🔍 Validating complete model setup...")
        do {
            try await ModelSetupValidator.validateModelFiles(at: modelCache.modelPath)
        } catch {
            print("❌ Model validation failed: \(error)")
            
            // Get user-friendly recovery suggestion
            let suggestion = ModelSetupValidator.getRecoverySuggestion(for: error)
            throw ModelError.downloadFailed(suggestion)
        }
        
        downloadState = .completed
        progress = 1.0
    }
    
    private func downloadFile(_ file: ModelFile) async throws {
        let fullURL = URL(string: baseURL + file.url)!
        let destinationURL = modelCache.modelPath.appendingPathComponent(file.name)
        
        // Check for resume data
        let resumeDataURL = destinationURL.appendingPathExtension("download")
        var resumeData: Data?
        
        if FileManager.default.fileExists(atPath: resumeDataURL.path) {
            resumeData = try? Data(contentsOf: resumeDataURL)
        }
        
        // Get token before entering continuation
        let token = SettingsManager.shared.getHuggingFaceToken()
        
        return try await withCheckedThrowingContinuation { continuation in
            let completionHandler: @Sendable (URL?, URLResponse?, Error?) -> Void = { [weak self] tempURL, response, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        // Save resume data if available
                        if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                            try? resumeData.write(to: resumeDataURL)
                        }
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let tempURL = tempURL else {
                        continuation.resume(throwing: URLError(.unknown))
                        return
                    }
                    
                    // Check HTTP response status
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                            let authError = ModelError.downloadFailed("Download failed (HTTP \(httpResponse.statusCode)). The model access may have changed. Please try again later.")
                            continuation.resume(throwing: authError)
                            return
                        } else if httpResponse.statusCode >= 400 {
                            let httpError = ModelError.downloadFailed("HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                            continuation.resume(throwing: httpError)
                            return
                        }
                    }
                    
                    do {
                        // Validate the downloaded file before moving
                        let fileData = try Data(contentsOf: tempURL)
                        
                        // Check if it's HTML error page
                        if let htmlCheck = String(data: fileData.prefix(1000), encoding: .utf8),
                           (htmlCheck.contains("<!DOCTYPE") || htmlCheck.contains("<html") || 
                            htmlCheck.contains("401") || htmlCheck.contains("403") ||
                            htmlCheck.contains("error") || htmlCheck.contains("Error")) {
                            
                            // Extract error message if possible
                            var errorMessage = "Download failed - received error page instead of model data"
                            if htmlCheck.contains("401") || htmlCheck.contains("Unauthorized") {
                                errorMessage = "Download failed. This is usually temporary - please try again in a few minutes."
                            } else if htmlCheck.contains("403") || htmlCheck.contains("Forbidden") {
                                errorMessage = "Model access issue. Please try again later."
                            }
                            
                            throw ModelError.downloadFailed(errorMessage)
                        }
                        
                        // Validate file size - be more specific about expected sizes
                        let actualSize = fileData.count
                        let expectedSize = file.size
                        
                        // Allow some tolerance for size differences (5% or 10KB, whichever is larger)
                        // This accounts for variations in HuggingFace's reported sizes
                        let tolerance = max(10240, Int(Double(expectedSize) * 0.05))
                        let isValidSize = abs(actualSize - Int(expectedSize)) <= tolerance
                        
                        if !isValidSize {
                            let formatter = ByteCountFormatter()
                            formatter.countStyle = .file
                            let actualFormatted = formatter.string(fromByteCount: Int64(actualSize))
                            let expectedFormatted = formatter.string(fromByteCount: expectedSize)
                            
                            // More helpful error message
                            var errorMsg = "Downloaded file \(file.name) size mismatch:\n"
                            errorMsg += "Expected: \(expectedFormatted) (\(expectedSize) bytes)\n"
                            errorMsg += "Received: \(actualFormatted) (\(actualSize) bytes)\n"
                            
                            if actualSize < 1000 && file.name.contains(".json") {
                                errorMsg += "\nThis might be an authentication error. The download returned an error page instead of the actual file."
                            } else if actualSize < Int(expectedSize) / 2 {
                                errorMsg += "\nThe download appears to be incomplete. Please try again."
                            }
                            
                            throw ModelError.downloadFailed(errorMsg)
                        }
                        
                        // Move file to destination
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.removeItem(at: destinationURL)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                        
                        // Clean up resume data
                        try? FileManager.default.removeItem(at: resumeDataURL)
                        
                        // Update progress
                        self.bytesDownloaded += file.size
                        self.updateOverallProgress()
                        
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Create download task
            let task: URLSessionDownloadTask
            if let resumeData = resumeData {
                task = session.downloadTask(withResumeData: resumeData, completionHandler: completionHandler)
            } else {
                var request = URLRequest(url: fullURL)
                request.httpMethod = "GET"
                request.setValue("Gemi/1.0", forHTTPHeaderField: "User-Agent")
                
                // Add HuggingFace authentication if token exists
                if let token = token {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    print("🔐 Using HuggingFace token for authentication (token starts with: \(String(token.prefix(7)))...)")
                } else {
                    print("⚠️ No HuggingFace token found - this will fail for gated models!")
                }
                
                task = session.downloadTask(with: request, completionHandler: completionHandler)
            }
            
            downloadTasks.append(task)
            task.resume()
        }
    }
    
    private func verifyFile(at url: URL, expectedHash: String) async throws -> Bool {
        // If we don't have a hash, just check file exists
        guard !expectedHash.isEmpty && expectedHash != "pending" else {
            return FileManager.default.fileExists(atPath: url.path)
        }
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        
        // Calculate SHA-256
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }
            
            var hasher = SHA256()
            let bufferSize = 1024 * 1024 // 1MB chunks
            
            while autoreleasepool(invoking: {
                let data = fileHandle.readData(ofLength: bufferSize)
                guard !data.isEmpty else { return false }
                hasher.update(data: data)
                return true
            }) {}
            
            let digest = hasher.finalize()
            let calculatedHash = digest.map { String(format: "%02x", $0) }.joined()
            
            // Compare hashes
            let matches = calculatedHash.lowercased() == expectedHash.lowercased()
            
            if !matches {
                print("⚠️ SHA-256 mismatch for \(url.lastPathComponent)")
                print("  Expected: \(expectedHash)")
                print("  Calculated: \(calculatedHash)")
            }
            
            return matches
        } catch {
            print("Error calculating SHA-256 for \(url.lastPathComponent): \(error)")
            return false
        }
    }
    
    private func fetchAndUpdateFileHashes() async {
        do {
            let metadata = try await fetchFileMetadata()
            
            // Update our file list with SHA256 hashes
            for (index, file) in requiredFiles.enumerated() {
                if let meta = metadata.first(where: { $0.filename == file.name }),
                   let sha256 = meta.sha256 {
                    requiredFiles[index].sha256 = sha256
                }
            }
            
            print("✅ Fetched SHA-256 hashes for \(metadata.filter { $0.sha256 != nil }.count) files")
        } catch {
            // If we can't fetch metadata, continue without SHA verification
            print("⚠️ Could not fetch file metadata: \(error.localizedDescription)")
            print("   Continuing without SHA-256 verification")
        }
    }
    
    private func verifyAllFiles() async throws {
        for file in requiredFiles {
            let localPath = modelCache.modelPath.appendingPathComponent(file.name)
            guard try await verifyFile(at: localPath, expectedHash: file.sha256) else {
                throw ModelError.verificationFailed(file.name)
            }
        }
    }
    
    private func updateOverallProgress() {
        let newProgress = Double(bytesDownloaded) / Double(totalBytes)
        
        Task { @MainActor in
            self.progress = min(1.0, max(0.0, newProgress))
            
            // Calculate download speed
            if let startTime = self.downloadStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > 0 {
                    self.downloadSpeed = Double(self.bytesDownloaded) / elapsed
                }
            }
            
            if downloadTasks.first(where: { $0.state == .running }) != nil {
                self.currentFile = "Downloading model files..."
            }
            
            self.downloadState = .downloading(
                file: self.currentFile,
                progress: self.progress
            )
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession,
                   downloadTask: URLSessionDownloadTask,
                   didWriteData bytesWritten: Int64,
                   totalBytesWritten: Int64,
                   totalBytesExpectedToWrite: Int64) {
        
        Task { @MainActor in
            if totalBytesExpectedToWrite > 0 {
                _ = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                
                // Update current file progress
                if let fileName = downloadTask.originalRequest?.url?.lastPathComponent {
                    self.currentFile = fileName
                }
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession,
                   downloadTask: URLSessionDownloadTask,
                   didFinishDownloadingTo location: URL) {
        // Handled in completion handler
    }
    
    nonisolated func urlSession(_ session: URLSession,
                   task: URLSessionTask,
                   didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.error = error
                self.downloadState = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Model Error

enum ModelError: LocalizedError {
    case downloadFailed(String)
    case verificationFailed(String)
    case extractionFailed(String)
    case modelNotFound
    case modelNotLoaded
    case invalidConfiguration
    case authenticationRequired(String)
    case invalidFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .verificationFailed(let file):
            return "Verification failed for: \(file)"
        case .extractionFailed(let reason):
            return "Extraction failed: \(reason)"
        case .modelNotFound:
            return "Model files not found"
        case .modelNotLoaded:
            return "Model not loaded"
        case .invalidConfiguration:
            return "Invalid model configuration"
        case .authenticationRequired(let message):
            return message
        case .invalidFormat(let reason):
            return "Invalid format: \(reason)"
        }
    }
}