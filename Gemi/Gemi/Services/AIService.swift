import Foundation

/// Service for communicating with the Gemi AI inference server
/// Provides multimodal support for text, images, and audio
actor AIService {
    static let shared = AIService()
    
    // MARK: - Properties
    
    private let session: URLSession
    private var modelName = "google/gemma-3n-e4b-it"
    
    // Connection state caching
    private var lastHealthCheck: Date?
    private var cachedHealthStatus: Bool = false
    private let healthCheckCacheDuration: TimeInterval = 30.0
    
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
    
    /// Check if the AI server is running and ready
    func checkHealth() async throws -> Bool {
        // Use cached result if available and recent
        if let lastCheck = lastHealthCheck,
           Date().timeIntervalSince(lastCheck) < healthCheckCacheDuration {
            return cachedHealthStatus
        }
        
        do {
            let healthURL = URL(string: await AIConfiguration.shared.apiHealthURL)!
            let (data, response) = try await session.data(from: healthURL)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse("Invalid response type")
            }
            
            guard httpResponse.statusCode == 200 else {
                throw AIServiceError.serviceUnavailable("AI service returned status \(httpResponse.statusCode)")
            }
            
            // Parse health response
            if let healthData = try? JSONDecoder().decode(HealthResponse.self, from: data) {
                let isReady = healthData.model_loaded && healthData.status == "healthy"
                
                // Cache the result
                lastHealthCheck = Date()
                cachedHealthStatus = isReady
                
                return isReady
            }
            
            return false
            
        } catch {
            // Cache negative result too
            lastHealthCheck = Date()
            cachedHealthStatus = false
            
            if error is AIServiceError {
                throw error
            } else {
                throw AIServiceError.connectionFailed(error.localizedDescription)
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
    
    /// Check if the current model supports multimodal input
    func isMultimodalModel() async -> Bool {
        // Gemma 3n is always multimodal
        return true
    }
    
    private func performChatRequest(messages: [ChatMessage], continuation: AsyncThrowingStream<ChatResponse, Error>.Continuation) async {
        var retryCount = 0
        
        while retryCount <= maxRetries {
            do {
                // Build request
                let url = URL(string: await AIConfiguration.shared.apiChatURL)!
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
                    throw AIServiceError.invalidResponse("Invalid response type")
                }
                
                if httpResponse.statusCode == 503 {
                    // Model still loading
                    if let data = try? await bytes.reduce(into: Data(), { data, byte in
                        data.append(byte)
                    }),
                       let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data),
                       errorResponse.detail.contains("Progress:") {
                        throw AIServiceError.modelLoading(errorResponse.detail)
                    }
                    throw AIServiceError.serviceUnavailable("Model not ready")
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw AIServiceError.invalidResponse("HTTP \(httpResponse.statusCode)")
                }
                
                // Process streaming response
                // Process streaming response line by line
                
                for try await line in bytes.lines {
                    guard !line.isEmpty else { continue }
                    
                    // Handle SSE format: data: {...}
                    if line.hasPrefix("data: ") {
                        let jsonString = String(line.dropFirst(6))
                        
                        if let data = jsonString.data(using: .utf8) {
                            do {
                                let response = try JSONDecoder().decode(ChatResponse.self, from: data)
                                continuation.yield(response)
                                
                                if response.done {
                                    continuation.finish()
                                    return
                                }
                            } catch {
                                // Handle parsing errors
                                print("Failed to parse response: \(jsonString)")
                                continue
                            }
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
        let num_predict: Int  // Changed from num_ctx to match Python server
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
        case .serviceUnavailable(let details):
            return "AI service is not running. \(details)\n\nPlease ensure:\n1. Inference server is running\n2. The server will start automatically when needed"
            
        case .connectionFailed(let details):
            return "Failed to connect to AI service: \(details)"
            
        case .modelLoading(let details):
            return "Model is loading: \(details)"
            
        case .invalidResponse(let details):
            return "Invalid response from AI service: \(details)"
            
        case .timeout:
            return "Request timed out. Please check your connection and try again."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .serviceUnavailable:
            return "The inference server will start automatically when needed"
            
        case .modelLoading:
            return "Please wait for the model to finish downloading"
            
        default:
            return "Try restarting the inference server or check your network connection"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let aiServiceStatusChanged = Notification.Name("aiServiceStatusChanged")
}