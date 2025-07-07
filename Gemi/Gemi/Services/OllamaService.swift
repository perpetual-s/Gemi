import Foundation

/// Service for communicating with Ollama API
/// Rebuilt from scratch with proper error handling and Swift 6 compliance
actor OllamaService {
    static let shared = OllamaService()
    
    // MARK: - Properties
    
    private let session: URLSession
    private let modelName = "gemma3n:latest" // Correct model name
    
    // Connection state caching
    private var lastHealthCheck: Date?
    private var cachedHealthStatus: Bool = false
    private let healthCheckCacheDuration: TimeInterval = 30.0 // 30 seconds to reduce UI blinking
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelay: UInt64 = 1_000_000_000 // 1 second in nanoseconds
    
    // MARK: - Initialization
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Health Check
    
    /// Check if Ollama is running and the model is available
    func checkHealth() async throws -> Bool {
        // Use cached result if available and recent
        if let lastCheck = lastHealthCheck,
           Date().timeIntervalSince(lastCheck) < healthCheckCacheDuration {
            return cachedHealthStatus
        }
        
        do {
            // First check if Ollama is running
            let tagsURL = URL(string: await OllamaConfiguration.shared.apiTagsURL)!
            let (data, response) = try await session.data(from: tagsURL)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaError.invalidResponse("Invalid response type")
            }
            
            guard httpResponse.statusCode == 200 else {
                throw OllamaError.serviceUnavailable("Ollama service returned status \(httpResponse.statusCode)")
            }
            
            // Parse available models
            let models = try JSONDecoder().decode(ModelsResponse.self, from: data)
            let availableModels = models.models.map { $0.name }
            
            // Debug logging removed to reduce console noise
            // print("Available models: \(availableModels.joined(separator: ", "))")
            // print("Looking for: \(modelName)")
            
            // Check if our model is available
            let hasModel = availableModels.contains { model in
                model == modelName || model.hasPrefix("gemma3n")
            }
            
            if !hasModel {
                print("Model \(modelName) not found. Please run: ollama pull \(modelName)")
                throw OllamaError.modelNotFound(modelName)
            }
            
            // Cache the result
            lastHealthCheck = Date()
            cachedHealthStatus = true
            
            return true
            
        } catch {
            // Cache negative result too
            lastHealthCheck = Date()
            cachedHealthStatus = false
            
            if error is OllamaError {
                throw error
            } else {
                throw OllamaError.connectionFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Chat with Streaming
    
    /// Generate a response using the chat endpoint with streaming
    func chat(messages: [ChatMessage]) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.performChatRequest(messages: messages, continuation: continuation)
            }
        }
    }
    
    private func performChatRequest(messages: [ChatMessage], continuation: AsyncThrowingStream<ChatResponse, Error>.Continuation) async {
        var retryCount = 0
        
        while retryCount <= maxRetries {
            do {
                // Build request
                let url = URL(string: await OllamaConfiguration.shared.apiChatURL)!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let chatRequest = ChatRequest(
                    model: modelName,
                    messages: messages,
                    stream: true
                )
                
                request.httpBody = try JSONEncoder().encode(chatRequest)
                
                // Start streaming
                let (bytes, response) = try await session.bytes(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OllamaError.invalidResponse("Invalid response type")
                }
                
                if httpResponse.statusCode == 404 {
                    throw OllamaError.modelNotFound(modelName)
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw OllamaError.invalidResponse("HTTP \(httpResponse.statusCode)")
                }
                
                // Process streaming response
                var buffer = ""
                
                for try await line in bytes.lines {
                    guard !line.isEmpty else { continue }
                    
                    // Handle potential partial JSON by buffering
                    buffer += line
                    
                    if let data = buffer.data(using: .utf8) {
                        do {
                            let response = try JSONDecoder().decode(ChatResponse.self, from: data)
                            continuation.yield(response)
                            buffer = "" // Clear buffer on successful parse
                            
                            if response.done {
                                continuation.finish()
                                return
                            }
                        } catch {
                            // If JSON parsing fails, continue buffering
                            continue
                        }
                    }
                }
                
                continuation.finish()
                return
                
            } catch {
                retryCount += 1
                
                if retryCount > maxRetries {
                    continuation.finish(throwing: error)
                    return
                }
                
                // Wait before retry
                try? await Task.sleep(nanoseconds: retryDelay * UInt64(retryCount))
                print("Retrying request (attempt \(retryCount)/\(maxRetries))...")
            }
        }
    }
    
    // MARK: - Model Management
    
    /// Pull a model from Ollama library with progress tracking
    func pullModel(_ modelName: String, progressHandler: @escaping @Sendable (Double, String) -> Void) async throws {
        let url = URL(string: await OllamaConfiguration.shared.apiPullURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let pullRequest = PullModelRequest(name: modelName, stream: true)
        request.httpBody = try JSONEncoder().encode(pullRequest)
        
        let (bytes, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.modelPullFailed("Failed to pull model \(modelName)")
        }
        
        var totalSize: Int64 = 0
        var completedSize: Int64 = 0
        
        for try await line in bytes.lines {
            guard !line.isEmpty else { continue }
            
            if let data = line.data(using: .utf8),
               let pullResponse = try? JSONDecoder().decode(PullResponse.self, from: data) {
                
                if let total = pullResponse.total {
                    totalSize = total
                }
                
                if let completed = pullResponse.completed {
                    completedSize = completed
                }
                
                let progress = totalSize > 0 ? Double(completedSize) / Double(totalSize) : 0
                let status = pullResponse.status ?? "Downloading..."
                
                await MainActor.run {
                    progressHandler(progress, status)
                }
                
                if pullResponse.status?.contains("success") == true {
                    break
                }
            }
        }
    }
}

// MARK: - Data Models

struct ChatMessage: Codable, Sendable {
    let role: Role
    let content: String
    
    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }
}

struct ChatRequest: Codable, Sendable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
    let options: Options?
    
    init(model: String, messages: [ChatMessage], stream: Bool = true) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.options = Options()
    }
    
    struct Options: Codable, Sendable {
        let temperature: Double
        let num_ctx: Int
        let top_p: Double
        let top_k: Int
        
        init(temperature: Double = 0.7, num_ctx: Int = 4096, top_p: Double = 0.9, top_k: Int = 40) {
            self.temperature = temperature
            self.num_ctx = num_ctx
            self.top_p = top_p
            self.top_k = top_k
        }
    }
}

struct ChatResponse: Codable, Sendable {
    let model: String
    let created_at: String
    let message: ChatMessage?
    let done: Bool
    let total_duration: Int64?
    let eval_count: Int?
    let prompt_eval_count: Int?
}

struct PullModelRequest: Codable, Sendable {
    let name: String
    let stream: Bool?
}

struct PullResponse: Codable, Sendable {
    let status: String?
    let digest: String?
    let total: Int64?
    let completed: Int64?
}

struct ModelsResponse: Codable, Sendable {
    let models: [Model]
    
    struct Model: Codable, Sendable {
        let name: String
        let modified_at: String
        let size: Int64
        let digest: String
    }
}

// MARK: - Errors

enum OllamaError: LocalizedError {
    case serviceUnavailable(String)
    case connectionFailed(String)
    case modelNotFound(String)
    case modelPullFailed(String)
    case invalidResponse(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable(let details):
            return "Ollama service is not running. \(details)\n\nPlease ensure:\n1. Ollama is installed\n2. Run 'ollama serve' in Terminal"
            
        case .connectionFailed(let details):
            return "Failed to connect to Ollama: \(details)"
            
        case .modelNotFound(let model):
            return "Model '\(model)' not found.\n\nPlease run: ollama pull \(model)"
            
        case .modelPullFailed(let details):
            return "Failed to pull model: \(details)"
            
        case .invalidResponse(let details):
            return "Invalid response from Ollama: \(details)"
            
        case .timeout:
            return "Request timed out. Please check your connection and try again."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .serviceUnavailable:
            return "Open Terminal and run: ollama serve"
            
        case .modelNotFound(let model):
            return "Open Terminal and run: ollama pull \(model)"
            
        default:
            return "Try restarting Ollama or check your network connection"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let ollamaServiceStatusChanged = Notification.Name("ollamaServiceStatusChanged")
}