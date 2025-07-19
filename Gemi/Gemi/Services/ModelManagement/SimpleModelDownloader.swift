import Foundation
import Combine

/// A simple, elegant model downloader that just works - like Python's mlx_lm.load()
@MainActor
final class SimpleModelDownloader: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isDownloading = false
    @Published var progress: Double = 0.0
    @Published var currentFile: String = ""
    @Published var statusMessage: String = ""
    @Published var bytesDownloaded: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var downloadSpeed: Double = 0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    
    // MARK: - Types
    
    enum DownloadError: LocalizedError {
        case networkError(String)
        case fileError(String)
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .networkError(let message):
                return "Network error: \(message)"
            case .fileError(let message):
                return "File error: \(message)"
            case .cancelled:
                return "Download cancelled"
            }
        }
    }
    
    // MARK: - Properties
    
    private let modelID = ModelConfiguration.modelID
    private let modelCache = ModelCache.shared
    private var downloadTasks: [URLSessionDownloadTask] = []
    private var session: URLSession!
    private var startTime: Date?
    private var fileProgress: [String: Int64] = [:]
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupURLSession()
    }
    
    // MARK: - Public Methods
    
    /// Download the model files - simple and straightforward
    func downloadModel() async throws {
        guard !isDownloading else { return }
        
        isDownloading = true
        progress = 0.0
        statusMessage = "Starting download..."
        startTime = Date()
        
        // Calculate total size
        totalBytes = ModelConfiguration.totalSize
        
        // Check existing files
        let filesToDownload = checkExistingFiles()
        
        if filesToDownload.isEmpty {
            statusMessage = "All files already downloaded!"
            progress = 1.0
            isDownloading = false
            return
        }
        
        // Download missing files
        try await downloadFiles(filesToDownload)
        
        // Validate all files
        try validateDownloadedFiles()
        
        statusMessage = "Download complete!"
        progress = 1.0
        isDownloading = false
    }
    
    /// Cancel the download
    func cancelDownload() {
        downloadTasks.forEach { $0.cancel() }
        downloadTasks.removeAll()
        isDownloading = false
        statusMessage = "Download cancelled"
    }
    
    // MARK: - Private Methods
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 3600.0 // 1 hour for large files
        config.httpMaximumConnectionsPerHost = 2
        
        // Setup headers with authentication
        var headers: [String: String] = [
            "User-Agent": "Gemi/1.0"
        ]
        
        // Add HuggingFace token if available
        if let token = SettingsManager.shared.getHuggingFaceToken() {
            headers["Authorization"] = "Bearer \(token)"
            print("✅ HuggingFace token configured for download")
        } else {
            print("⚠️ No HuggingFace token found - downloads may fail for gated models")
        }
        
        config.httpAdditionalHeaders = headers
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    private func checkExistingFiles() -> [(name: String, size: Int64)] {
        var filesToDownload: [(name: String, size: Int64)] = []
        var existingBytes: Int64 = 0
        
        for file in ModelConfiguration.requiredFiles {
            let localPath = modelCache.modelPath.appendingPathComponent(file.name)
            
            if FileManager.default.fileExists(atPath: localPath.path) {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: localPath.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    // Check if file size is valid
                    if ModelConfiguration.isValidSize(actual: fileSize, expected: file.size) {
                        existingBytes += file.size
                        fileProgress[file.name] = file.size
                        continue
                    }
                } catch {
                    // File check failed, re-download
                }
            }
            
            filesToDownload.append(file)
        }
        
        // Update progress for existing files
        bytesDownloaded = existingBytes
        if totalBytes > 0 {
            progress = Double(existingBytes) / Double(totalBytes)
        }
        
        return filesToDownload
    }
    
    private func downloadFiles(_ files: [(name: String, size: Int64)]) async throws {
        for file in files {
            currentFile = file.name
            statusMessage = "Downloading \(file.name)..."
            
            // Simple, direct URL - no complex fallbacks
            let urlString = "https://huggingface.co/\(modelID)/resolve/main/\(file.name)"
            guard let url = URL(string: urlString) else {
                throw DownloadError.networkError("Invalid URL for \(file.name)")
            }
            
            do {
                try await downloadSingleFile(file: file, from: url)
            } catch {
                // Clean error handling
                if (error as NSError).code == NSURLErrorCancelled {
                    throw DownloadError.cancelled
                } else {
                    throw DownloadError.networkError(error.localizedDescription)
                }
            }
        }
    }
    
    private func downloadSingleFile(file: (name: String, size: Int64), from url: URL) async throws {
        let destinationURL = modelCache.modelPath.appendingPathComponent(file.name)
        
        // Create directory if needed
        try FileManager.default.createDirectory(
            at: modelCache.modelPath,
            withIntermediateDirectories: true
        )
        
        // Download with progress tracking
        let (tempURL, response) = try await session.download(from: url) { [weak self] (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in
            Task { @MainActor in
                self?.updateProgress(for: file.name, bytesWritten: totalBytesWritten, totalBytes: file.size)
            }
        }
        
        // Validate response
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw DownloadError.networkError("Server returned status \(httpResponse.statusCode) for \(file.name)")
            }
        }
        
        // Move file to destination
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        // Update progress
        fileProgress[file.name] = file.size
    }
    
    private func updateProgress(for filename: String, bytesWritten: Int64, totalBytes: Int64) {
        fileProgress[filename] = bytesWritten
        
        // Calculate total progress
        let totalDownloaded = fileProgress.values.reduce(0, +)
        self.bytesDownloaded = totalDownloaded
        
        if self.totalBytes > 0 {
            self.progress = Double(totalDownloaded) / Double(self.totalBytes)
        }
        
        // Update speed and time remaining
        if let startTime = startTime {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 0 {
                downloadSpeed = Double(totalDownloaded) / elapsed
                if downloadSpeed > 0 {
                    let remaining = Double(self.totalBytes - totalDownloaded) / downloadSpeed
                    estimatedTimeRemaining = remaining
                }
            }
        }
    }
    
    private func validateDownloadedFiles() throws {
        for file in ModelConfiguration.requiredFiles {
            let localPath = modelCache.modelPath.appendingPathComponent(file.name)
            
            guard FileManager.default.fileExists(atPath: localPath.path) else {
                throw DownloadError.fileError("\(file.name) is missing after download")
            }
            
            // Validate size
            let attributes = try FileManager.default.attributesOfItem(atPath: localPath.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            guard ModelConfiguration.isValidSize(actual: fileSize, expected: file.size) else {
                throw DownloadError.fileError("\(file.name) has incorrect size")
            }
            
            // Validate JSON files can be parsed
            if file.name.hasSuffix(".json") {
                let data = try Data(contentsOf: localPath)
                _ = try JSONSerialization.jsonObject(with: data)
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension SimpleModelDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Handled in async download method
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // Progress updates handled in async download method
    }
}

// MARK: - URLSession Extension

extension URLSession {
    /// Simple async download with progress callback
    func download(
        from url: URL,
        progress: @escaping @Sendable (Int64, Int64, Int64) -> Void
    ) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.downloadTask(with: url) { url, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url, let response = response {
                    continuation.resume(returning: (url, response))
                } else {
                    continuation.resume(throwing: URLError(.unknown))
                }
            }
            
            // Simple progress observation
            let observation = task.progress.observe(\.fractionCompleted, options: [.new]) { taskProgress, _ in
                progress(
                    Int64(taskProgress.completedUnitCount),
                    Int64(taskProgress.totalUnitCount),
                    Int64(taskProgress.totalUnitCount)
                )
            }
            
            task.resume()
            
            // Keep observation alive
            withExtendedLifetime(observation) {}
        }
    }
}