import Foundation

/// Service for AI inference using Ollama
/// Provides stable multimodal support for text, images, and audio
actor AIService {
    static let shared = AIService()
    
    // MARK: - Properties
    
    private let modelName = "gemma3n:latest"
    
    // Connection state caching
    private var lastHealthCheck: Date?
    private var cachedHealthStatus: Bool = false
    private let healthCheckCacheDuration: TimeInterval = 30.0
    
    // MARK: - Initialization
    
    private init() {
        // Initialize Ollama connection on startup
        Task {
            await checkAndSetupOllama()
        }
    }
    
    // MARK: - Health Check
    
    /// Check if the AI model is loaded and ready
    func checkHealth() async throws -> Bool {
        // Use cached result if available and recent
        if let lastCheck = lastHealthCheck,
           Date().timeIntervalSince(lastCheck) < healthCheckCacheDuration {
            return cachedHealthStatus
        }
        
        // Access MainActor-isolated shared instance and call health
        let health = await OllamaChatService.shared.health()
        let isReady = health.healthy && health.modelLoaded
        
        // Cache the result
        lastHealthCheck = Date()
        cachedHealthStatus = isReady
        
        return isReady
    }
    
    // MARK: - Private Methods
    
    private func checkAndSetupOllama() async {
        // Check if Ollama is installed and running
        let health = await OllamaChatService.shared.health()
        if !health.healthy {
            // Try to start Ollama if installed
            _ = try? await OllamaInstaller.shared.startOllamaServer()
        }
    }
    
    // MARK: - Chat with Streaming
    
    /// Generate a response using Ollama with streaming
    func chat(messages: [ChatMessage]) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.performChatRequest(messages: messages, continuation: continuation)
            }
        }
    }
    
    /// Generate a response with contextual temperature adjustment
    func chatWithContext(messages: [ChatMessage]) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.performChatRequest(messages: messages, continuation: continuation, useContextualTemperature: true)
            }
        }
    }
    
    /// Check if the current model supports multimodal input
    func isMultimodalModel() async -> Bool {
        // Gemma 3n via Ollama is always multimodal
        return true
    }
    
    private func performChatRequest(messages: [ChatMessage], continuation: AsyncThrowingStream<ChatResponse, Error>.Continuation, useContextualTemperature: Bool = false) async {
        do {
            // Ensure Ollama is ready
            if !(try await checkHealth()) {
                // Try to setup Ollama if not ready
                await checkAndSetupOllama()
                
                // Check again
                if !(try await checkHealth()) {
                    throw AIServiceError.serviceUnavailable("Ollama is not ready. Please ensure it's installed and running.")
                }
            }
            
            // Convert messages to Ollama format
            let ollamaMessages = messages.map { msg in
                OllamaChatService.ChatMessage(
                    role: msg.role.rawValue,
                    content: msg.content,
                    images: msg.images
                )
            }
            
            // Use configuration from AIConfiguration for dynamic control
            let config = await AIConfiguration.shared
            
            // Determine temperature based on context if requested
            let effectiveTemperature: Double
            if useContextualTemperature, let lastUserMessage = messages.last(where: { $0.role == .user }) {
                effectiveTemperature = await config.getContextualTemperature(for: lastUserMessage.content)
            } else {
                effectiveTemperature = await config.temperature
            }
            
            let maxTokens = await config.maxTokens
            
            let request = OllamaChatService.ChatRequest(
                messages: ollamaMessages,
                model: modelName,
                stream: true,
                options: OllamaChatService.ChatOptions(
                    temperature: effectiveTemperature,
                    maxTokens: maxTokens,
                    topK: 64,  // Gemma 3n optimal setting
                    topP: 0.95  // Gemma 3n optimal setting
                )
            )
            
            // Get streaming response from Ollama
            let chatStream = try await OllamaChatService.shared.chat(request)
            
            for try await response in chatStream {
                // Convert Ollama response to expected format
                // Always include the message for streaming responses
                let chatResponse = ChatResponse(
                    model: modelName,
                    created_at: ISO8601DateFormatter().string(from: Date()),
                    message: ChatMessage(
                        role: .assistant,
                        content: response.message.content
                    ),
                    done: response.done,
                    total_duration: response.totalDuration,
                    eval_count: response.evalCount,
                    prompt_eval_count: response.promptEvalCount
                )
                
                continuation.yield(chatResponse)
                
                if response.done {
                    continuation.finish()
                    return
                }
            }
            
            continuation.finish()
            
        } catch {
            continuation.finish(throwing: error)
        }
    }
}

// MARK: - Data Models

struct ChatMessage: Codable, Sendable {
    let role: Role
    let content: String
    let images: [String]? // Base64 encoded images for multimodal
    
    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }
    
    init(role: Role, content: String, images: [String]? = nil) {
        self.role = role
        self.content = content
        self.images = images
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
        let num_predict: Int  // Maximum tokens to generate
        let top_p: Double
        let top_k: Int
        
        init(temperature: Double = 0.7, num_predict: Int = 2048, top_p: Double = 0.9, top_k: Int = 40) {
            self.temperature = temperature
            self.num_predict = num_predict
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

struct HealthResponse: Codable, Sendable {
    let status: String
    let model_loaded: Bool
    let device: String
    let mps_available: Bool
    let download_progress: Double
}

struct ErrorResponse: Codable, Sendable {
    let detail: String
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

enum AIServiceError: LocalizedError {
    case serviceUnavailable(String)
    case connectionFailed(String)
    case modelLoading(String)
    case invalidResponse(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable(_):
            return "AI service is starting up"
            
        case .connectionFailed(_):
            return "Connection to AI service failed"
            
        case .modelLoading(_):
            return "AI model is downloading"
            
        case .invalidResponse(_):
            return "Unexpected response from AI service"
            
        case .timeout:
            return "Request timed out"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .serviceUnavailable(let details):
            if details.contains("503") || details.contains("loading") {
                return "The AI is starting up. This usually takes 10-30 seconds."
            }
            return "Gemi will automatically start the AI service."
            
        case .connectionFailed:
            return "The AI service will restart automatically. Please try again in a moment."
            
        case .modelLoading(let details):
            if details.contains("%") {
                return "First-time download in progress. This only happens once."
            }
            return "Please wait while the AI model downloads (~8GB)."
            
        case .invalidResponse:
            return "Please try your request again."
            
        case .timeout:
            return "The request is taking longer than expected. Try a simpler message."
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let aiServiceStatusChanged = Notification.Name("aiServiceStatusChanged")
}