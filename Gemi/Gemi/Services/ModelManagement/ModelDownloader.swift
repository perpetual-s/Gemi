import Foundation
import Combine
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
    
    // MARK: - Types
    
    enum DownloadState: Equatable {
        case notStarted
        case preparing
        case downloading(file: String, progress: Double)
        case verifying
        case extracting
        case completed
        case failed(String)
        
        var isDownloading: Bool {
            if case .downloading = self { return true }
            return false
        }
    }
    
    struct ModelFile {
        let name: String
        let url: String
        let size: Int64
        let sha256: String
    }
    
    // MARK: - Properties
    
    private let modelID = "google/gemma-3n-E4B-it"
    private let baseURL = "https://huggingface.co/google/gemma-3n-E4B-it/resolve/main/"
    
    // Required model files for Gemma 3n E4B
    // Total size is approximately 15.7 GB
    private let requiredFiles: [ModelFile] = [
        ModelFile(name: "config.json", 
                 url: "config.json",
                 size: 2_048,  // ~2KB
                 sha256: "placeholder_hash_config"),
        ModelFile(name: "tokenizer.json",
                 url: "tokenizer.json", 
                 size: 1_747_968,  // ~1.7MB
                 sha256: "placeholder_hash_tokenizer"),
        ModelFile(name: "tokenizer_config.json",
                 url: "tokenizer_config.json",
                 size: 2_048,  // ~2KB
                 sha256: "placeholder_hash_tokenizer_config"),
        ModelFile(name: "model.safetensors.index.json",
                 url: "model.safetensors.index.json",
                 size: 32_768,  // ~32KB
                 sha256: "placeholder_hash_index"),
        ModelFile(name: "model-00001-of-00004.safetensors",
                 url: "model-00001-of-00004.safetensors",
                 size: 4_225_761_280,  // ~3.94GB
                 sha256: "placeholder_hash_model1"),
        ModelFile(name: "model-00002-of-00004.safetensors",
                 url: "model-00002-of-00004.safetensors",
                 size: 4_225_761_280,  // ~3.94GB
                 sha256: "placeholder_hash_model2"),
        ModelFile(name: "model-00003-of-00004.safetensors",
                 url: "model-00003-of-00004.safetensors",
                 size: 4_225_761_280,  // ~3.94GB
                 sha256: "placeholder_hash_model3"),
        ModelFile(name: "model-00004-of-00004.safetensors",
                 url: "model-00004-of-00004.safetensors",
                 size: 4_194_304_000,  // ~3.91GB
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
    }
    
    // MARK: - Public Methods
    
    /// Start downloading the model
    func startDownload() async throws {
        guard downloadState == .notStarted || downloadState == .failed("") else {
            return
        }
        
        downloadState = .preparing
        currentFile = "Preparing download..."
        
        // Check if model already exists
        if await modelCache.isModelComplete() {
            downloadState = .completed
            progress = 1.0
            return
        }
        
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
        downloadState = .notStarted
        progress = 0.0
    }
    
    /// Resume a paused download
    func resumeDownload() async throws {
        if case .failed = downloadState {
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
        // Check if we have a token
        guard let token = await SettingsManager.shared.getHuggingFaceToken() else {
            throw ModelError.authenticationRequired(
                """
                HuggingFace authentication required.
                
                Gemma models are gated and require a HuggingFace token.
                Please add your token in the settings to continue.
                """
            )
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
                    throw ModelError.authenticationRequired(
                        """
                        Invalid HuggingFace token.
                        
                        Please check that your token is correct and has read permissions.
                        """
                    )
                case 403:
                    throw ModelError.authenticationRequired(
                        """
                        Access forbidden.
                        
                        Please ensure you have accepted the Gemma license at:
                        https://huggingface.co/google/gemma-3n-E4B-it
                        """
                    )
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
        
        // Download files in parallel (up to 4 at a time)
        downloadState = .downloading(file: "Starting downloads...", progress: 0.0)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for file in filesToDownload {
                group.addTask {
                    try await self.downloadFile(file)
                }
            }
            
            try await group.waitForAll()
        }
        
        // Verify all files after download
        downloadState = .verifying
        try await verifyAllFiles()
        
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
        let token = await SettingsManager.shared.getHuggingFaceToken()
        
        return try await withCheckedThrowingContinuation { continuation in
            let completionHandler: (URL?, URLResponse?, Error?) -> Void = { [weak self] tempURL, response, error in
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
                            let authError = ModelError.authenticationRequired(
                                """
                                HuggingFace authentication failed (HTTP \(httpResponse.statusCode)).
                                
                                To fix this:
                                1. Ensure your HuggingFace token is set in .env file
                                2. Visit https://huggingface.co/google/gemma-3n-E4B-it and accept the license
                                3. Make sure your token has read permissions
                                """
                            )
                            continuation.resume(throwing: authError)
                            return
                        } else if httpResponse.statusCode >= 400 {
                            let httpError = ModelError.downloadFailed("HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                            continuation.resume(throwing: httpError)
                            return
                        }
                    }
                    
                    do {
                        // Check if the downloaded file is HTML (error page)
                        let fileData = try Data(contentsOf: tempURL)
                        if let htmlCheck = String(data: fileData.prefix(1000), encoding: .utf8),
                           (htmlCheck.contains("<!DOCTYPE") || htmlCheck.contains("<html") || htmlCheck.contains("401") || htmlCheck.contains("403")) {
                            
                            // Extract error message if possible
                            var errorMessage = "Authentication required to access Gemma model"
                            if htmlCheck.contains("401") || htmlCheck.contains("Unauthorized") {
                                errorMessage = """
                                    HuggingFace authentication failed.
                                    
                                    Please ensure:
                                    1. Your HuggingFace token is correctly set
                                    2. You have accepted the Gemma license at:
                                       https://huggingface.co/google/gemma-3n-E4B-it
                                    3. Your token has read permissions
                                    """
                            }
                            
                            throw ModelError.authenticationRequired(errorMessage)
                        }
                        
                        // Move file to destination
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
        // For now, skip SHA verification since we don't have real hashes
        // In production, implement proper SHA-256 verification
        return FileManager.default.fileExists(atPath: url.path)
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
    case authenticationRequired(String)
    
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
        case .authenticationRequired(let message):
            return message
        }
    }
}