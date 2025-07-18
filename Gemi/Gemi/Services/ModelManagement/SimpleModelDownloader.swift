import Foundation

/// Ultra-simple, ultra-robust model downloader
/// No fancy progress bars, just downloads that work
@MainActor
final class SimpleModelDownloader: ObservableObject {
    @Published var isDownloading = false
    @Published var statusMessage = ""
    @Published var error: String?
    
    private let modelPath = ModelCache.shared.modelPath
    private let requiredFiles = ModelFileSpecs.gemma3nE4B
    
    func downloadModel() async throws {
        isDownloading = true
        error = nil
        
        do {
            // Step 1: Get the token
            statusMessage = "Checking authentication..."
            let token = getHuggingFaceToken()
            if token.isEmpty {
                throw SimpleDownloadError.noToken
            }
            
            // Step 2: Create model directory
            try FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)
            
            // Step 3: Download each file
            for (index, file) in requiredFiles.enumerated() {
                statusMessage = "Downloading file \(index + 1) of \(requiredFiles.count): \(file.name)"
                
                let localPath = modelPath.appendingPathComponent(file.name)
                
                // Skip if already exists and valid
                if FileManager.default.fileExists(atPath: localPath.path) {
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: localPath.path),
                       let fileSize = attributes[.size] as? Int64,
                       abs(fileSize - file.size) < (file.size / 20) { // 5% tolerance
                        print("✅ File already exists: \(file.name)")
                        continue
                    }
                }
                
                // Download the file
                try await downloadFile(file, token: token, to: localPath)
            }
            
            statusMessage = "Download complete!"
            isDownloading = false
            
        } catch {
            self.error = error.localizedDescription
            statusMessage = "Download failed"
            isDownloading = false
            throw error
        }
    }
    
    private func getHuggingFaceToken() -> String {
        // Try .env first
        if let token = EnvironmentConfig.shared.huggingFaceToken, !token.isEmpty {
            print("✅ Using token from .env")
            return token
        }
        
        // Try keychain
        if let token = SettingsManager.shared.getHuggingFaceToken(), !token.isEmpty {
            print("✅ Using token from keychain")
            return token
        }
        
        print("❌ No HuggingFace token found!")
        return ""
    }
    
    private func downloadFile(_ file: ModelFile, token: String, to localPath: URL) async throws {
        let urlString = "https://huggingface.co/google/gemma-3n-E4B-it/resolve/main/\(file.name)?download=true"
        guard let url = URL(string: urlString) else {
            throw SimpleDownloadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300 // 5 minutes per file
        
        // Try up to 3 times
        for attempt in 1...3 {
            do {
                print("📥 Downloading \(file.name) (attempt \(attempt))...")
                
                let (tempURL, response) = try await URLSession.shared.download(for: request)
                
                // Check response
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        // Success - move file
                        try? FileManager.default.removeItem(at: localPath)
                        try FileManager.default.moveItem(at: tempURL, to: localPath)
                        print("✅ Downloaded \(file.name)")
                        return
                        
                    case 401, 403:
                        throw SimpleDownloadError.authenticationFailed
                        
                    default:
                        throw SimpleDownloadError.httpError(httpResponse.statusCode)
                    }
                }
                
            } catch {
                print("⚠️ Attempt \(attempt) failed: \(error)")
                if attempt == 3 {
                    throw error
                }
                // Wait before retry
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }
}

enum SimpleDownloadError: LocalizedError {
    case noToken
    case invalidURL
    case authenticationFailed
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No HuggingFace token found. Please ensure the app was built correctly."
        case .invalidURL:
            return "Invalid download URL"
        case .authenticationFailed:
            return "Authentication failed. Please accept the Gemma model license at huggingface.co/google/gemma-3n-E4B-it"
        case .httpError(let code):
            return "Download failed with error code: \(code)"
        }
    }
}