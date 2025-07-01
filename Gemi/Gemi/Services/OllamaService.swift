//
//  OllamaService.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import Foundation
import os.log

/// Ollama API response models
struct OllamaModel: Codable {
    let name: String
    let modified_at: String
    let size: Int64
    let digest: String
}

struct OllamaModelList: Codable {
    let models: [OllamaModel]
}

struct OllamaChatRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: OllamaOptions?
    let context: [Int]?
}

struct OllamaOptions: Codable {
    let temperature: Double?
    let top_p: Double?
    let top_k: Int?
    let repeat_penalty: Double?
    let seed: Int?
    let num_predict: Int?
    let num_ctx: Int?
}

struct OllamaChatResponse: Codable {
    let model: String
    let created_at: String
    let response: String
    let done: Bool
    let context: [Int]?
    let total_duration: Int?
    let load_duration: Int?
    let prompt_eval_count: Int?
    let prompt_eval_duration: Int?
    let eval_count: Int?
    let eval_duration: Int?
}

struct OllamaEmbeddingRequest: Codable {
    let model: String
    let prompt: String
}

struct OllamaEmbeddingResponse: Codable {
    let embedding: [Double]
}

struct OllamaPullRequest: Codable {
    let name: String
    let stream: Bool
}

struct OllamaPullResponse: Codable {
    let status: String
    let digest: String?
    let total: Int64?
    let completed: Int64?
}

/// Errors specific to Ollama operations
enum OllamaError: LocalizedError {
    case modelNotInstalled
    case connectionFailed
    case invalidResponse
    case streamingError
    case modelDownloadFailed
    case embeddingGenerationFailed
    case serverNotRunning
    case invalidURL
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotInstalled:
            return "Gemma 3n model is not installed. Please install it through Ollama."
        case .connectionFailed:
            return "Unable to connect to Ollama. Please ensure Ollama is running on your Mac."
        case .invalidResponse:
            return "Received an invalid response from Ollama."
        case .streamingError:
            return "Error occurred while streaming the response."
        case .modelDownloadFailed:
            return "Failed to download the Gemma 3n model."
        case .embeddingGenerationFailed:
            return "Failed to generate embeddings for the text."
        case .serverNotRunning:
            return "Ollama server is not running. Please start Ollama and try again."
        case .invalidURL:
            return "Invalid Ollama server URL configuration."
        case .unknownError(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
}

/// Swift 6 Observable service for managing Ollama AI interactions
@Observable
final class OllamaService {
    
    // MARK: - Singleton
    
    static let shared = OllamaService()
    
    // MARK: - Published Properties
    
    /// Whether Ollama is currently processing a request
    var isProcessing: Bool = false
    
    /// Current processing status message
    var statusMessage: String = ""
    
    /// Whether the required model is installed
    var isModelInstalled: Bool = false
    
    /// Download progress for model installation (0.0 to 1.0)
    var downloadProgress: Double = 0.0
    
    /// Current error if any
    var currentError: OllamaError?
    
    // MARK: - Private Properties
    
    private let baseURL = "http://localhost:11434"
    private let modelName = "gemma2:2b"  // Using smaller Gemma 2B for better performance
    private let embeddingModelName = "nomic-embed-text"  // Specialized embedding model
    
    private let session: URLSession
    private let logger = Logger(subsystem: "com.gemi.app", category: "OllamaService")
    
    private var activeTask: URLSessionDataTask?
    private var contextCache: [Int]?
    
    // Model configuration
    private let defaultOptions = OllamaOptions(
        temperature: 0.7,
        top_p: 0.9,
        top_k: 40,
        repeat_penalty: 1.1,
        seed: nil,
        num_predict: 2048,
        num_ctx: 4096
    )
    
    // MARK: - Initialization
    
    init() {
        // Configure URLSession with appropriate timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300 // 5 minutes for model downloads
        self.session = URLSession(configuration: configuration)
        
        // Check model status on initialization
        Task {
            await checkModelStatus()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check if Ollama is running and accessible
    @MainActor
    func checkOllamaStatus() async -> Bool {
        logger.info("Checking Ollama server status")
        
        do {
            let url = URL(string: "\(baseURL)/api/tags")!
            let (_, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                logger.info("Ollama server is running")
                return true
            }
        } catch {
            logger.error("Ollama server check failed: \(error.localizedDescription)")
        }
        
        return false
    }
    
    /// Check if the required models are installed
    @MainActor
    func checkModelStatus() async {
        logger.info("Checking installed models")
        
        guard await checkOllamaStatus() else {
            currentError = .serverNotRunning
            isModelInstalled = false
            return
        }
        
        do {
            let url = URL(string: "\(baseURL)/api/tags")!
            let (data, _) = try await session.data(from: url)
            let modelList = try JSONDecoder().decode(OllamaModelList.self, from: data)
            
            // Check if our required models are installed
            let installedModelNames = modelList.models.map { $0.name }
            let hasMainModel = installedModelNames.contains(where: { $0.hasPrefix("gemma") })
            let hasEmbeddingModel = installedModelNames.contains(embeddingModelName)
            
            isModelInstalled = hasMainModel && hasEmbeddingModel
            
            if !isModelInstalled {
                logger.warning("Required models not found. Main model: \(hasMainModel), Embedding model: \(hasEmbeddingModel)")
                currentError = .modelNotInstalled
            } else {
                logger.info("All required models are installed")
                currentError = nil
            }
            
        } catch {
            logger.error("Failed to check model status: \(error.localizedDescription)")
            currentError = .connectionFailed
            isModelInstalled = false
        }
    }
    
    /// Generate a chat completion with streaming support
    @MainActor
    func chatCompletion(prompt: String, context: [Int]? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.performChatCompletion(prompt: prompt, context: context, continuation: continuation)
            }
        }
    }
    
    /// Generate embeddings for a text
    @MainActor
    func generateEmbedding(for text: String) async throws -> [Double] {
        logger.info("Generating embedding for text")
        
        guard await checkOllamaStatus() else {
            throw OllamaError.serverNotRunning
        }
        
        isProcessing = true
        statusMessage = "Generating embedding..."
        
        defer {
            isProcessing = false
            statusMessage = ""
        }
        
        let url = URL(string: "\(baseURL)/api/embeddings")!
        let request = OllamaEmbeddingRequest(model: embeddingModelName, prompt: text)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw OllamaError.embeddingGenerationFailed
            }
            
            let embeddingResponse = try JSONDecoder().decode(OllamaEmbeddingResponse.self, from: data)
            logger.info("Successfully generated embedding with \(embeddingResponse.embedding.count) dimensions")
            
            return embeddingResponse.embedding
            
        } catch {
            logger.error("Embedding generation failed: \(error.localizedDescription)")
            throw OllamaError.embeddingGenerationFailed
        }
    }
    
    /// Pull (download) a model from Ollama
    @MainActor
    func pullModel(modelName: String) async throws {
        logger.info("Starting model download: \(modelName)")
        
        guard await checkOllamaStatus() else {
            throw OllamaError.serverNotRunning
        }
        
        isProcessing = true
        statusMessage = "Downloading \(modelName)..."
        downloadProgress = 0.0
        
        defer {
            isProcessing = false
            statusMessage = ""
            downloadProgress = 0.0
        }
        
        let url = URL(string: "\(baseURL)/api/pull")!
        let request = OllamaPullRequest(name: modelName, stream: true)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (bytes, response) = try await session.bytes(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.modelDownloadFailed
        }
        
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let pullResponse = try? JSONDecoder().decode(OllamaPullResponse.self, from: data) else {
                continue
            }
            
            if let total = pullResponse.total,
               let completed = pullResponse.completed,
               total > 0 {
                downloadProgress = Double(completed) / Double(total)
                statusMessage = pullResponse.status
            }
            
            logger.debug("Pull status: \(pullResponse.status)")
        }
        
        logger.info("Model download completed: \(modelName)")
        await checkModelStatus()
    }
    
    /// Cancel any active operations
    func cancelActiveOperations() {
        activeTask?.cancel()
        activeTask = nil
        isProcessing = false
        statusMessage = ""
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func performChatCompletion(prompt: String, context: [Int]?, continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        logger.info("Starting chat completion")
        
        guard await checkOllamaStatus() else {
            continuation.finish(throwing: OllamaError.serverNotRunning)
            return
        }
        
        isProcessing = true
        statusMessage = "Thinking..."
        
        defer {
            isProcessing = false
            statusMessage = ""
        }
        
        let url = URL(string: "\(baseURL)/api/generate")!
        let chatRequest = OllamaChatRequest(
            model: modelName,
            prompt: prompt,
            stream: true,
            options: defaultOptions,
            context: context ?? contextCache
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(chatRequest)
            let (bytes, response) = try await session.bytes(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw OllamaError.invalidResponse
            }
            
            var fullResponse = ""
            
            for try await line in bytes.lines {
                guard let data = line.data(using: .utf8),
                      let chatResponse = try? JSONDecoder().decode(OllamaChatResponse.self, from: data) else {
                    continue
                }
                
                if !chatResponse.response.isEmpty {
                    fullResponse += chatResponse.response
                    continuation.yield(chatResponse.response)
                }
                
                if chatResponse.done {
                    // Cache context for conversation continuity
                    if let context = chatResponse.context {
                        contextCache = context
                    }
                    
                    logger.info("Chat completion finished. Total tokens: \(chatResponse.eval_count ?? 0)")
                    break
                }
            }
            
            continuation.finish()
            
        } catch {
            logger.error("Chat completion error: \(error.localizedDescription)")
            continuation.finish(throwing: error)
        }
    }
    
    /// Clear conversation context
    func clearContext() {
        contextCache = nil
        logger.info("Conversation context cleared")
    }
    
    /// Get formatted status for UI display
    func getFormattedStatus() -> String {
        if isProcessing {
            return statusMessage
        } else if !isModelInstalled {
            return "Gemma model not installed"
        } else if currentError != nil {
            return "Ollama connection error"
        } else {
            return "Ready"
        }
    }
    
    /// Create a custom prompt with memory context
    func createPromptWithMemory(userMessage: String, memories: [String]) -> String {
        var prompt = ""
        
        if !memories.isEmpty {
            prompt += "Context from previous conversations:\n"
            for memory in memories.prefix(5) { // Limit to 5 most relevant memories
                prompt += "- \(memory)\n"
            }
            prompt += "\n"
        }
        
        prompt += "Current message: \(userMessage)\n\n"
        prompt += "Please respond as a supportive diary companion, acknowledging any context from previous conversations when relevant."
        
        return prompt
    }
}

// MARK: - Convenience Extensions

extension OllamaService {
    /// Check if Ollama needs to be installed or configured
    var needsSetup: Bool {
        !isModelInstalled || currentError == .serverNotRunning
    }
    
    /// Get user-friendly setup instructions
    var setupInstructions: String {
        if currentError == .serverNotRunning {
            return """
            Ollama is not running. Please:
            1. Install Ollama from https://ollama.ai
            2. Open Terminal and run: ollama serve
            3. Restart Gemi
            """
        } else if !isModelInstalled {
            return """
            The AI model needs to be installed. Please:
            1. Open Terminal
            2. Run: ollama pull gemma2:2b
            3. Run: ollama pull nomic-embed-text
            4. Wait for downloads to complete
            5. Restart Gemi
            """
        }
        return ""
    }
    
    /// Generate a chat completion and return full response
    func generateChat(prompt: String, model: String? = nil) async throws -> String {
        logger.info("Generating chat response")
        
        guard await checkOllamaStatus() else {
            throw OllamaError.serverNotRunning
        }
        
        let url = URL(string: "\(baseURL)/api/generate")!
        let chatRequest = OllamaChatRequest(
            model: model ?? modelName,
            prompt: prompt,
            stream: false,
            options: defaultOptions,
            context: nil
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(chatRequest)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.invalidResponse
        }
        
        let chatResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        return chatResponse.response
    }
    
    /// Generate a chat completion with streaming (new method for EnhancedChatView)
    func generateChatStream(prompt: String, model: String? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.performChatCompletion(
                    prompt: prompt,
                    context: nil,
                    continuation: continuation
                )
            }
        }
    }
    
    /// Generate embedding (overload for Float return type)
    func generateEmbedding(prompt: String, model: String) async throws -> OllamaEmbeddingResponse {
        logger.info("Generating embedding for text")
        
        guard await checkOllamaStatus() else {
            throw OllamaError.serverNotRunning
        }
        
        let url = URL(string: "\(baseURL)/api/embeddings")!
        let request = OllamaEmbeddingRequest(model: model, prompt: prompt)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.embeddingGenerationFailed
        }
        
        return try JSONDecoder().decode(OllamaEmbeddingResponse.self, from: data)
    }
    
    /// List available models
    func listModels() async throws -> [String] {
        guard await checkOllamaStatus() else {
            throw OllamaError.serverNotRunning
        }
        
        let url = URL(string: "\(baseURL)/api/tags")!
        let (data, _) = try await session.data(from: url)
        let modelList = try JSONDecoder().decode(OllamaModelList.self, from: data)
        
        return modelList.models.map { $0.name }
    }
}