import Foundation

/// Interface for HuggingFace API to fetch model metadata
@MainActor
final class HuggingFaceAPI {
    
    // MARK: - Types
    
    struct ModelInfo: Codable {
        let id: String
        let modelId: String
        let author: String?
        let gated: Bool?
        let pipeline_tag: String?
        let tags: [String]?
        let downloads: Int?
        let library_name: String?
        let siblings: [FileSibling]?
        
        private enum CodingKeys: String, CodingKey {
            case id, modelId, author, gated, tags, downloads, siblings
            case pipeline_tag = "pipeline_tag"
            case library_name = "library_name"
        }
    }
    
    struct FileSibling: Codable {
        let rfilename: String
        let size: Int64?
        let lfs: LFSPointer?
        
        var filename: String { rfilename }
        
        struct LFSPointer: Codable {
            let size: Int64
            let sha256: String
            let pointer_size: Int
        }
    }
    
    struct FileMetadata {
        let filename: String
        let size: Int64
        let sha256: String?
    }
    
    // MARK: - Properties
    
    static let shared = HuggingFaceAPI()
    private let session = URLSession.shared
    private let apiBaseURL = "https://huggingface.co/api"
    
    // MARK: - Public Methods
    
    /// Fetch model information including file metadata
    func fetchModelInfo(repoId: String) async throws -> ModelInfo {
        let url = URL(string: "\(apiBaseURL)/models/\(repoId)")!
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Gemi/1.0", forHTTPHeaderField: "User-Agent")
        
        // Add authentication if available
        if let token = SettingsManager.shared.getHuggingFaceToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        // Check response
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        // Decode model info
        do {
            let modelInfo = try JSONDecoder().decode(ModelInfo.self, from: data)
            return modelInfo
        } catch {
            print("Failed to decode model info: \(error)")
            throw APIError.decodingError(error)
        }
    }
    
    /// Get file metadata including SHA256 hashes
    func getFileMetadata(repoId: String) async throws -> [FileMetadata] {
        let modelInfo = try await fetchModelInfo(repoId: repoId)
        
        guard let siblings = modelInfo.siblings else {
            return []
        }
        
        return siblings.compactMap { sibling in
            // For LFS files, we have the SHA256
            if let lfs = sibling.lfs {
                return FileMetadata(
                    filename: sibling.filename,
                    size: lfs.size,
                    sha256: lfs.sha256
                )
            } else {
                // For non-LFS files, we don't have SHA256 from API
                return FileMetadata(
                    filename: sibling.filename,
                    size: sibling.size ?? 0,
                    sha256: nil
                )
            }
        }
    }
    
    /// Fetch SHA256 hash for a specific file
    func fetchFileSHA256(repoId: String, filename: String) async throws -> String? {
        let metadata = try await getFileMetadata(repoId: repoId)
        return metadata.first { $0.filename == filename }?.sha256
    }
    
    /// Check if model is gated
    func isModelGated(repoId: String) async throws -> Bool {
        let modelInfo = try await fetchModelInfo(repoId: repoId)
        return modelInfo.gated ?? false
    }
    
    /// Fetch model index file (for sharded models)
    func fetchModelIndex(repoId: String) async throws -> ModelIndex? {
        let indexURL = "https://huggingface.co/\(repoId)/resolve/main/model.safetensors.index.json"
        
        var request = URLRequest(url: URL(string: indexURL)!)
        request.setValue("Gemi/1.0", forHTTPHeaderField: "User-Agent")
        
        if let token = SettingsManager.shared.getHuggingFaceToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 404 {
                // No index file means single file model
                return nil
            }
            
            let index = try JSONDecoder().decode(ModelIndex.self, from: data)
            return index
        } catch {
            // If no index file exists, it's a single file model
            return nil
        }
    }
    
    // MARK: - Types
    
    struct ModelIndex: Codable {
        let metadata: IndexMetadata
        let weight_map: [String: String]
        
        struct IndexMetadata: Codable {
            let total_size: Int64?
        }
    }
    
    enum APIError: LocalizedError {
        case httpError(statusCode: Int)
        case decodingError(Error)
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .httpError(let code):
                return "HTTP Error \(code)"
            case .decodingError(let error):
                return "Failed to parse response: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - ModelDownloader Extension

extension ModelDownloader {
    /// Fetch and cache file metadata from HuggingFace API
    func fetchFileMetadata() async throws -> [HuggingFaceAPI.FileMetadata] {
        let repoId = "google/gemma-3n-E4B-it"
        return try await HuggingFaceAPI.shared.getFileMetadata(repoId: repoId)
    }
    
    /// Get SHA256 for a specific file
    func getFileSHA256(_ filename: String) async throws -> String? {
        let metadata = try await fetchFileMetadata()
        return metadata.first { $0.filename == filename }?.sha256
    }
}