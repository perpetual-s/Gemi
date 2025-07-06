import Foundation

/// Service for communicating with Ollama API
actor OllamaService {
    static let shared = OllamaService()
    
    private let baseURL = "http://localhost:11434"
    private let session: URLSession
    
    /// The model name to use for all API calls
    private let modelName = "gemma3n:latest"
    
    /// Custom model name for Gemi companion
    private let companionModelName = "gemi-companion"
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }
    
    /// Check if Ollama is running and the model is available
    func checkHealth() async throws -> Bool {
        let url = URL(string: "\(baseURL)/api/tags")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return false
        }
        
        // Check if our model is available
        if let models = try? JSONDecoder().decode(ModelsResponse.self, from: data) {
            return models.models.contains { $0.name == modelName || $0.name == companionModelName }
        }
        
        return false
    }
    
    /// Generate a response using the chat endpoint with streaming
    func chat(messages: [ChatMessage], context: String? = nil) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = URL(string: "\(baseURL)/api/chat")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    // Build the request with context if provided
                    var finalMessages = messages
                    if let context = context {
                        // Inject context as a system message at the beginning
                        let systemMessage = ChatMessage(
                            role: .system,
                            content: """
                            You are Gemi, a thoughtful and empathetic AI companion. \
                            Here's what you know about the user from their journal entries:
                            
                            \(context)
                            
                            Use this information to provide personalized, supportive responses. \
                            Remember past conversations and experiences they've shared.
                            """
                        )
                        finalMessages.insert(systemMessage, at: 0)
                    }
                    
                    let chatRequest = ChatRequest(
                        model: companionModelName.isEmpty ? modelName : companionModelName,
                        messages: finalMessages,
                        stream: true
                    )
                    
                    request.httpBody = try JSONEncoder().encode(chatRequest)
                    
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw OllamaError.invalidResponse
                    }
                    
                    // Process streaming response
                    for try await line in bytes.lines {
                        guard !line.isEmpty else { continue }
                        
                        if let data = line.data(using: .utf8),
                           let response = try? JSONDecoder().decode(ChatResponse.self, from: data) {
                            continuation.yield(response)
                            
                            if response.done {
                                break
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Create a custom model with our Modelfile
    func createCompanionModel(systemPrompt: String) async throws {
        let url = URL(string: "\(baseURL)/api/create")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let modelfile = """
        FROM \(modelName)
        
        TEMPLATE \"\"\"{{ if .System }}System: {{ .System }}
        {{ end }}{{ if .Prompt }}User: {{ .Prompt }}
        {{ end }}Assistant: {{ .Response }}\"\"\"
        
        SYSTEM "\(systemPrompt)"
        
        PARAMETER temperature 0.7
        PARAMETER top_p 0.9
        PARAMETER top_k 40
        PARAMETER num_ctx 4096
        """
        
        let createRequest = CreateModelRequest(
            name: companionModelName,
            modelfile: modelfile
        )
        
        request.httpBody = try JSONEncoder().encode(createRequest)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.modelCreationFailed
        }
    }
    
    /// Pull a model from Ollama library with progress tracking
    func pullModel(_ modelName: String, progressHandler: (@Sendable (Double, String) -> Void)? = nil) async throws {
        let url = URL(string: "\(baseURL)/api/pull")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let pullRequest = PullModelRequest(name: modelName, stream: true)
        request.httpBody = try JSONEncoder().encode(pullRequest)
        
        let (bytes, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.modelPullFailed
        }
        
        var totalSize: Int64 = 0
        var completedSize: Int64 = 0
        
        // Process streaming response
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
                
                // Calculate progress
                let progress = totalSize > 0 ? Double(completedSize) / Double(totalSize) : 0
                let status = pullResponse.status ?? "Downloading..."
                
                // Call progress handler on main thread
                if let handler = progressHandler {
                    await MainActor.run {
                        handler(progress, status)
                    }
                }
                
                // Post notification for UI updates
                NotificationCenter.default.post(
                    name: .ollamaModelDownloading,
                    object: nil,
                    userInfo: [
                        "progress": progress,
                        "status": status,
                        "completed": completedSize,
                        "total": totalSize
                    ]
                )
                
                // Check if download is complete
                if pullResponse.status?.contains("success") == true {
                    break
                }
            }
        }
    }
}

// MARK: - Data Models

struct ChatMessage: Codable {
    let role: Role
    let content: String
    
    enum Role: String, Codable {
        case system
        case user
        case assistant
    }
}

struct ChatRequest: Codable {
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
    
    struct Options: Codable {
        let temperature: Double
        let num_ctx: Int
        
        init(temperature: Double = 0.7, num_ctx: Int = 4096) {
            self.temperature = temperature
            self.num_ctx = num_ctx
        }
    }
}

struct ChatResponse: Codable {
    let model: String
    let created_at: String
    let message: ChatMessage?
    let done: Bool
    let total_duration: Int64?
    let eval_count: Int?
}

struct CreateModelRequest: Codable {
    let name: String
    let modelfile: String
}

struct PullModelRequest: Codable {
    let name: String
    let stream: Bool?
}

struct PullResponse: Codable {
    let status: String?
    let digest: String?
    let total: Int64?
    let completed: Int64?
}

struct ModelsResponse: Codable {
    let models: [Model]
    
    struct Model: Codable {
        let name: String
        let modified_at: String
        let size: Int64
    }
}

// MARK: - Errors

enum OllamaError: LocalizedError {
    case invalidResponse
    case modelNotFound
    case modelCreationFailed
    case modelPullFailed
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Ollama service"
        case .modelNotFound:
            return "The required model is not available"
        case .modelCreationFailed:
            return "Failed to create custom model"
        case .modelPullFailed:
            return "Failed to pull model from Ollama"
        case .serviceUnavailable:
            return "Ollama service is not running. Please start Ollama first."
        }
    }
}