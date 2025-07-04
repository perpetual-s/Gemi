//
//  OllamaService.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import Foundation
import SwiftUI
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

struct OllamaChatMessage: Codable {
    let role: String
    let content: String
}

struct OllamaChatRequestV2: Codable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
    let options: OllamaOptions?
}

struct OllamaChatResponseV2: Codable {
    let model: String
    let created_at: String
    let message: OllamaChatMessage
    let done: Bool
    let total_duration: Int?
    let load_duration: Int?
    let prompt_eval_count: Int?
    let prompt_eval_duration: Int?
    let eval_count: Int?
    let eval_duration: Int?
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
enum OllamaError: LocalizedError, Equatable {
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
@MainActor
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
    private let modelName = "gemma3n:latest"  // Using Gemma 3n latest for hackathon
    private let embeddingModelName = "nomic-embed-text:latest"  // Specialized embedding model
    
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
        
        // Delay initial check to allow app to fully initialize
        Task {
            // Wait for OllamaLauncher to do its work first
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Check if Ollama is running
            if OllamaLauncher.shared.status == .running {
                await checkModelStatus()
            } else {
                // Subscribe to launcher status changes
                logger.info("Waiting for Ollama to be ready")
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Check if Ollama is running and accessible
    @MainActor
    func checkOllamaStatus() async -> Bool {
        logger.info("Checking Ollama server status")
        
        // Try multiple times with short delay
        for attempt in 1...3 {
            do {
                guard let url = URL(string: "\(baseURL)/api/tags") else {
                    logger.error("Invalid URL for Ollama status check")
                    return false
                }
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 5.0 // Quick timeout for status check
                
                let (_, response) = try await session.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    logger.info("Ollama server is running")
                    return true
                }
            } catch {
                logger.error("Ollama server check attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Wait before retry, except on last attempt
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
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
            guard let url = URL(string: "\(baseURL)/api/tags") else {
                currentError = .invalidURL
                isModelInstalled = false
                return
            }
            
            let (data, _) = try await session.data(from: url)
            let modelList = try JSONDecoder().decode(OllamaModelList.self, from: data)
            
            // Check if our required models are installed
            let installedModelNames = modelList.models.map { $0.name }
            logger.info("Installed models: \(installedModelNames.joined(separator: ", "))")
            
            // Check for main model (gemma3n variants)
            let hasMainModel = installedModelNames.contains(where: { name in
                name.hasPrefix("gemma3n") || name == self.modelName
            })
            
            // Check for embedding model
            let hasEmbeddingModel = installedModelNames.contains(where: { name in
                name.hasPrefix("nomic-embed-text") || name == self.embeddingModelName
            })
            
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
                await self.performChatCompletionV2(prompt: prompt, continuation: continuation)
            }
        }
    }
    
    /// Stream chat completion for Gemi with proper message structure
    func gemiChatCompletion(userMessage: String, memories: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let messages = createChatMessages(userMessage: userMessage, memories: memories)
                await self.performChatCompletionV2(prompt: userMessage, messages: messages, continuation: continuation)
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
            // Use retry logic for the network request
            let (data, response) = try await performWithRetry {
                try await session.data(for: urlRequest)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaError.embeddingGenerationFailed
            }
            
            // Check for specific HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                // Success, continue processing
                break
            case 404:
                // Model not found - don't retry this
                logger.error("Embedding model not found: \(self.embeddingModelName)")
                throw OllamaError.modelNotInstalled
            case 500...599:
                // Server error - worth retrying
                logger.error("Server error: HTTP \(httpResponse.statusCode)")
                throw OllamaError.connectionFailed
            default:
                logger.error("Unexpected HTTP status: \(httpResponse.statusCode)")
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
        let normalizedModelName = modelName
        logger.info("Starting model download: \(normalizedModelName)")
        
        guard await checkOllamaStatus() else {
            throw OllamaError.serverNotRunning
        }
        
        isProcessing = true
        statusMessage = "Downloading \(normalizedModelName)..."
        downloadProgress = 0.0
        
        defer {
            isProcessing = false
            statusMessage = ""
            downloadProgress = 0.0
        }
        
        let url = URL(string: "\(baseURL)/api/pull")!
        let request = OllamaPullRequest(name: normalizedModelName, stream: true)
        
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
        
        logger.info("Model download completed: \(normalizedModelName)")
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
    
    /// Perform an operation with exponential backoff retry logic
    private func performWithRetry<T: Sendable>(
        maxAttempts: Int = 3,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if it's a model not found error - no point retrying
                if let urlError = error as? URLError,
                   urlError.code == .badServerResponse {
                    // This might be a model not found error, don't retry
                    throw OllamaError.modelNotInstalled
                }
                
                if attempt < maxAttempts {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = UInt64(pow(2.0, Double(attempt - 1))) * 1_000_000_000
                    
                    // Update status message to show retry attempt
                    await MainActor.run {
                        self.statusMessage = "Retrying connection (attempt \(attempt + 1)/\(maxAttempts))..."
                    }
                    
                    try? await Task.sleep(nanoseconds: delay)
                    
                    logger.info("Retrying operation after \(pow(2.0, Double(attempt - 1)))s delay (attempt \(attempt + 1)/\(maxAttempts))")
                }
            }
        }
        
        // All attempts failed
        throw lastError ?? OllamaError.connectionFailed
    }
    
    @MainActor
    private func performChatCompletionV2(prompt: String, messages: [OllamaChatMessage]? = nil, continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        logger.info("Starting chat completion with /api/chat endpoint")
        
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
        
        let url = URL(string: "\(baseURL)/api/chat")!
        
        // Use provided messages or fall back to simple user message
        let chatMessages = messages ?? [OllamaChatMessage(role: "user", content: prompt)]
        
        let chatRequest = OllamaChatRequestV2(
            model: modelName,
            messages: chatMessages,
            stream: true,
            options: defaultOptions
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(chatRequest)
            
            // Use retry logic for the network request
            let (bytes, response) = try await performWithRetry {
                try await session.bytes(for: urlRequest)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaError.invalidResponse
            }
            
            // Check for specific HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                // Success, continue processing
                break
            case 404:
                // Model not found - don't retry this
                logger.error("Model not found: \(self.modelName)")
                throw OllamaError.modelNotInstalled
            case 500...599:
                // Server error - worth retrying
                logger.error("Server error: HTTP \(httpResponse.statusCode)")
                throw OllamaError.connectionFailed
            default:
                logger.error("Unexpected HTTP status: \(httpResponse.statusCode)")
                throw OllamaError.invalidResponse
            }
            
            var fullResponse = ""
            
            for try await line in bytes.lines {
                guard let data = line.data(using: .utf8),
                      let chatResponse = try? JSONDecoder().decode(OllamaChatResponseV2.self, from: data) else {
                    continue
                }
                
                if !chatResponse.message.content.isEmpty {
                    fullResponse += chatResponse.message.content
                    continuation.yield(chatResponse.message.content)
                }
                
                if chatResponse.done {
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
            
            // Use retry logic for the network request
            let (bytes, response) = try await performWithRetry {
                try await session.bytes(for: urlRequest)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaError.invalidResponse
            }
            
            // Check for specific HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                // Success, continue processing
                break
            case 404:
                // Model not found - don't retry this
                logger.error("Model not found: \(self.modelName)")
                throw OllamaError.modelNotInstalled
            case 500...599:
                // Server error - worth retrying
                logger.error("Server error: HTTP \(httpResponse.statusCode)")
                throw OllamaError.connectionFailed
            default:
                logger.error("Unexpected HTTP status: \(httpResponse.statusCode)")
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
        var prompt = """
        You are Gemi, a warm and empathetic AI diary companion. You're having a private conversation with your user in their personal journal app. Everything shared stays completely private on their device.
        
        Your personality:
        - Warm, supportive, and encouraging like a trusted friend
        - Reflective and thoughtful, helping users explore their feelings
        - Non-judgmental and accepting of all emotions and experiences
        - Gently curious, asking follow-up questions to help users reflect deeper
        - Celebrating small victories and providing comfort during difficult times
        
        Remember to:
        - Keep responses conversational and personal, not clinical
        - Use warm, friendly language that feels like chatting with a close friend
        - Acknowledge emotions and validate feelings
        - Offer gentle prompts for deeper reflection when appropriate
        - Reference past conversations naturally when relevant
        
        """
        
        if !memories.isEmpty {
            prompt += "\nContext from your previous conversations together:\n"
            for memory in memories.prefix(5) { // Limit to 5 most relevant memories
                prompt += "- \(memory)\n"
            }
            prompt += "\n"
        }
        
        prompt += "Your friend writes: \"\(userMessage)\"\n\n"
        prompt += "Respond as Gemi with warmth and empathy, keeping the conversation natural and supportive."
        
        return prompt
    }
    
    /// Create structured messages for chat API
    func createChatMessages(userMessage: String, memories: [String]) -> [OllamaChatMessage] {
        var systemPrompt = """
        You are Gemi, a warm and empathetic AI diary companion. You're having a private conversation with your user in their personal journal app. Everything shared stays completely private on their device.
        
        Your personality:
        - Warm, supportive, and encouraging like a trusted friend
        - Reflective and thoughtful, helping users explore their feelings
        - Non-judgmental and accepting of all emotions and experiences
        - Gently curious, asking follow-up questions to help users reflect deeper
        - Celebrating small victories and providing comfort during difficult times
        
        Remember to:
        - Keep responses conversational and personal, not clinical
        - Use warm, friendly language that feels like chatting with a close friend
        - Acknowledge emotions and validate feelings
        - Offer gentle prompts for deeper reflection when appropriate
        - Reference past conversations naturally when relevant
        """
        
        if !memories.isEmpty {
            systemPrompt += "\n\nContext from your previous conversations together:\n"
            for memory in memories.prefix(5) {
                systemPrompt += "- \(memory)\n"
            }
        }
        
        return [
            OllamaChatMessage(role: "system", content: systemPrompt),
            OllamaChatMessage(role: "user", content: userMessage)
        ]
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
            2. Run: ollama pull gemma3n:latest
            3. Run: ollama pull nomic-embed-text:latest
            4. Wait for downloads to complete
            5. Restart Gemi
            
            Note: Gemma 3n is optimized for everyday devices and supports 140+ languages.
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
        
        // Use retry logic for the network request
        let (data, response) = try await performWithRetry {
            try await session.data(for: urlRequest)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }
        
        // Check for specific HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            // Success, continue processing
            break
        case 404:
            // Model not found - don't retry this
            logger.error("Model not found: \(model ?? modelName)")
            throw OllamaError.modelNotInstalled
        case 500...599:
            // Server error - worth retrying
            logger.error("Server error: HTTP \(httpResponse.statusCode)")
            throw OllamaError.connectionFailed
        default:
            logger.error("Unexpected HTTP status: \(httpResponse.statusCode)")
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
        
        // Use retry logic for the network request
        let (data, response) = try await performWithRetry {
            try await session.data(for: urlRequest)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.embeddingGenerationFailed
        }
        
        // Check for specific HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            // Success, continue processing
            break
        case 404:
            // Model not found - don't retry this
            logger.error("Embedding model not found: \(model)")
            throw OllamaError.modelNotInstalled
        case 500...599:
            // Server error - worth retrying
            logger.error("Server error: HTTP \(httpResponse.statusCode)")
            throw OllamaError.connectionFailed
        default:
            logger.error("Unexpected HTTP status: \(httpResponse.statusCode)")
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
    
    /// Check if a specific model is installed (handles name variations)
    func isModelInstalled(_ modelName: String) async throws -> Bool {
        let models = try await listModels()
        return models.contains(where: { name in
            name == modelName || name.hasPrefix(modelName.split(separator: ":").first ?? "")
        })
    }
    
    /// Create a custom model from a Modelfile
    func createModel(name: String, modelfileContent: String) async throws {
        logger.info("Creating custom model: \(name)")
        
        guard await checkOllamaStatus() else {
            throw OllamaError.serverNotRunning
        }
        
        let normalizedName = name
        let url = URL(string: "\(baseURL)/api/create")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "name": normalizedName,
            "modelfile": modelfileContent
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.unknownError("Failed to create custom model")
        }
        
        logger.info("Successfully created custom model: \(normalizedName)")
    }
    
    // MARK: - Specialized Analysis Methods for Insights
    
    /// Analyze sentiment of journal entries
    func analyzeSentiment(text: String) async throws -> SentimentAnalysis {
        let prompt = """
        Analyze the sentiment and emotions in this journal entry. Return a JSON response with:
        - overall_sentiment: "positive", "negative", or "neutral"
        - confidence: 0.0 to 1.0
        - emotions: array of detected emotions with scores
        - key_phrases: phrases that indicate the sentiment
        
        Journal entry: "\(text)"
        
        Respond ONLY with valid JSON, no other text.
        """
        
        let response = try await generateChat(prompt: prompt)
        
        // Parse JSON response
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Fallback if JSON parsing fails
            return SentimentAnalysis(
                overallSentiment: "neutral",
                confidence: 0.5,
                emotions: [],
                keyPhrases: []
            )
        }
        
        return SentimentAnalysis(
            overallSentiment: json["overall_sentiment"] as? String ?? "neutral",
            confidence: json["confidence"] as? Double ?? 0.5,
            emotions: parseEmotions(json["emotions"] as? [[String: Any]] ?? []),
            keyPhrases: json["key_phrases"] as? [String] ?? []
        )
    }
    
    /// Extract topics from journal entries
    func extractTopics(entries: [String]) async throws -> [Topic] {
        let entriesText = entries.prefix(10).joined(separator: "\n\n---\n\n")
        
        let prompt = """
        Extract the main topics and themes from these journal entries. Return a JSON response with:
        - topics: array of topics, each with name, frequency (1-10), and related_words
        
        Journal entries:
        \(entriesText)
        
        Respond ONLY with valid JSON array of topics.
        """
        
        let response = try await generateChat(prompt: prompt)
        
        // Parse and return topics
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let topicsData = json["topics"] as? [[String: Any]] else {
            return []
        }
        
        return topicsData.compactMap { topicData in
            guard let name = topicData["name"] as? String,
                  let frequency = topicData["frequency"] as? Int else {
                return nil
            }
            
            return Topic(
                name: name,
                frequency: frequency,
                relatedWords: topicData["related_words"] as? [String] ?? []
            )
        }
    }
    
    /// Generate personalized insights
    func generateInsights(entries: [JournalEntry]) async throws -> [PersonalInsight] {
        let recentEntries = entries.prefix(10).map { entry in
            "Date: \(entry.date.formatted(date: .abbreviated, time: .omitted))\nMood: \(entry.mood ?? "unknown")\nContent: \(String(entry.content.prefix(200)))"
        }.joined(separator: "\n\n---\n\n")
        
        let prompt = """
        Based on these journal entries, generate 3-5 personalized insights about patterns, growth, and wellbeing.
        Focus on:
        - Happiness patterns (when/what makes them happy)
        - Stress triggers and coping mechanisms
        - Personal growth observations
        - Relationship patterns
        - Goal progress
        
        Return a JSON array of insights, each with:
        - type: "happiness", "stress", "growth", "relationships", or "goals"
        - title: short descriptive title (max 10 words)
        - description: detailed insight (2-3 sentences)
        - confidence: 0.0 to 1.0
        
        Journal entries:
        \(recentEntries)
        
        Respond ONLY with valid JSON array.
        """
        
        let response = try await generateChat(prompt: prompt)
        
        // Parse insights
        guard let data = response.data(using: String.Encoding.utf8),
              let insightsData = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        return insightsData.compactMap { insightData in
            guard let type = insightData["type"] as? String,
                  let title = insightData["title"] as? String,
                  let description = insightData["description"] as? String else {
                return nil
            }
            
            return PersonalInsight(
                type: InsightType(rawValue: type) ?? .general,
                title: title,
                description: description,
                confidence: insightData["confidence"] as? Double ?? 0.7,
                date: Date()
            )
        }
    }
    
    private func parseEmotions(_ emotionsData: [[String: Any]]) -> [Emotion] {
        return emotionsData.compactMap { emotionData in
            guard let name = emotionData["name"] as? String,
                  let score = emotionData["score"] as? Double else {
                return nil
            }
            
            return Emotion(name: name, score: score)
        }
    }
}

// MARK: - Supporting Types for Insights

struct SentimentAnalysis {
    let overallSentiment: String
    let confidence: Double
    let emotions: [Emotion]
    let keyPhrases: [String]
}

struct Emotion: Identifiable {
    let id = UUID()
    let name: String
    let score: Double
}

struct Topic: Identifiable {
    let id = UUID()
    let name: String
    let frequency: Int
    let relatedWords: [String]
}

enum InsightType: String {
    case happiness
    case stress
    case growth
    case relationships
    case goals
    case general
    
    var icon: String {
        switch self {
        case .happiness: return "sun.max.fill"
        case .stress: return "bolt.fill"
        case .growth: return "arrow.up.right.circle.fill"
        case .relationships: return "heart.fill"
        case .goals: return "target"
        case .general: return "lightbulb.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .happiness: return .yellow
        case .stress: return .red
        case .growth: return .green
        case .relationships: return .pink
        case .goals: return .blue
        case .general: return .purple
        }
    }
}

struct PersonalInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let confidence: Double
    let date: Date
}