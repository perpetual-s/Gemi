import Foundation

/// Production-grade Ollama chat service for Gemi
/// Replaces MLX-Swift with stable, multimodal-capable inference
@MainActor
final class OllamaChatService: ObservableObject {
    static let shared = OllamaChatService()
    
    // MARK: - Published Properties
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var modelStatus: ModelStatus = .notLoaded
    @Published var isGenerating = false
    
    // MARK: - Types
    
    enum ConnectionStatus {
        case connected
        case disconnected
        case connecting
        case error(String)
    }
    
    enum ModelStatus: Equatable {
        case notLoaded
        case loading(progress: Double)
        case loaded
        case error(String)
    }
    
    struct ChatRequest {
        let messages: [ChatMessage]
        let model: String
        let stream: Bool
        let options: ChatOptions?
    }
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
        let images: [String]? // Base64 encoded images
    }
    
    struct ChatOptions: Codable {
        let temperature: Double?
        let maxTokens: Int?
        let topK: Int?
        let topP: Double?
        
        private enum CodingKeys: String, CodingKey {
            case temperature
            case maxTokens = "num_predict"
            case topK = "top_k"
            case topP = "top_p"
        }
    }
    
    struct ChatResponse {
        let message: ChatMessage
        let done: Bool
        let totalDuration: Int64?
        let loadDuration: Int64?
        let promptEvalCount: Int?
        let evalCount: Int?
        let evalDuration: Int64?
    }
    
    struct HealthStatus {
        let healthy: Bool
        let modelLoaded: Bool
        let device: String
    }
    
    // MARK: - Private Properties
    
    private let baseURL = "http://localhost:11434"
    private let defaultModel = "gemma3n:latest"
    private let session: URLSession
    private var currentTask: Task<Void, Never>?
    
    // Health check cache
    private var lastHealthCheck: Date?
    private var cachedHealthStatus: HealthStatus?
    private let healthCheckCacheDuration: TimeInterval = 5.0
    
    // MARK: - Initialization
    
    private init() {
        // Configure URLSession for streaming
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes for long responses
        config.timeoutIntervalForResource = 600 // 10 minutes for model downloads
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
        
        // Start initial health check
        Task {
            await checkInitialStatus()
        }
    }
    
    // MARK: - Public Methods
    
    /// Send a chat request with streaming response
    func chat(_ request: ChatRequest) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        // Ensure Ollama is running
        if !(await isOllamaRunning()) {
            // Try to start Ollama
            try await startOllamaIfNeeded()
            
            // Check again after starting
            guard await isOllamaRunning() else {
                throw OllamaError.notRunning
            }
        }
        
        // Ensure model is available
        let modelName = request.model.isEmpty ? defaultModel : request.model
        guard await isModelAvailable(modelName) else {
            throw OllamaError.modelNotFound(modelName)
        }
        
        isGenerating = true
        
        return AsyncThrowingStream { continuation in
            currentTask = Task {
                do {
                    let url = URL(string: "\(baseURL)/api/chat")!
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    // Build Ollama request
                    let ollamaRequest = OllamaRequest(
                        model: modelName,
                        messages: request.messages.map { msg in
                            OllamaMessage(
                                role: msg.role,
                                content: msg.content,
                                images: msg.images
                            )
                        },
                        stream: request.stream,
                        options: request.options.map { opts in
                            OllamaOptions(
                                temperature: opts.temperature,
                                top_k: opts.topK,
                                top_p: opts.topP,
                                num_predict: opts.maxTokens,
                                num_ctx: 4096,
                                repeat_penalty: 1.1
                            )
                        },
                        keep_alive: "5m"
                    )
                    
                    urlRequest.httpBody = try JSONEncoder().encode(ollamaRequest)
                    
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    
                    // Check HTTP response
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode != 200 {
                        throw OllamaError.httpError(httpResponse.statusCode)
                    }
                    
                    // Process streaming response
                    var accumulatedContent = ""
                    
                    for try await line in bytes.lines {
                        // Check for task cancellation
                        if Task.isCancelled { break }
                        
                        guard let data = line.data(using: .utf8) else { continue }
                        
                        // Try to decode as error first
                        if let errorResponse = try? JSONDecoder().decode(OllamaErrorResponse.self, from: data) {
                            throw OllamaError.apiError(errorResponse.error)
                        }
                        
                        // Decode normal response
                        guard let ollamaResponse = try? JSONDecoder().decode(OllamaStreamResponse.self, from: data) else {
                            continue
                        }
                        
                        // Accumulate content
                        if let content = ollamaResponse.message?.content {
                            accumulatedContent += content
                        }
                        
                        // Convert to our response format
                        let chatResponse = ChatResponse(
                            message: ChatMessage(
                                role: "assistant",
                                content: request.stream ? (ollamaResponse.message?.content ?? "") : accumulatedContent,
                                images: nil
                            ),
                            done: ollamaResponse.done,
                            totalDuration: ollamaResponse.total_duration,
                            loadDuration: ollamaResponse.load_duration,
                            promptEvalCount: ollamaResponse.prompt_eval_count,
                            evalCount: ollamaResponse.eval_count,
                            evalDuration: ollamaResponse.eval_duration
                        )
                        
                        continuation.yield(chatResponse)
                        
                        if ollamaResponse.done {
                            break
                        }
                    }
                    
                    continuation.finish()
                    await MainActor.run {
                        self.isGenerating = false
                    }
                    
                } catch {
                    continuation.finish(throwing: error)
                    await MainActor.run {
                        self.isGenerating = false
                    }
                }
            }
        }
    }
    
    /// Get health status
    func health() async -> HealthStatus {
        // Use cached result if fresh
        if let lastCheck = lastHealthCheck,
           let cached = cachedHealthStatus,
           Date().timeIntervalSince(lastCheck) < healthCheckCacheDuration {
            return cached
        }
        
        // Perform fresh health check
        let isRunning = await isOllamaRunning()
        let hasModel = isRunning ? await isModelAvailable(defaultModel) : false
        
        let status = HealthStatus(
            healthy: isRunning && hasModel,
            modelLoaded: hasModel,
            device: "metal" // Ollama uses Metal on macOS
        )
        
        // Cache the result
        lastHealthCheck = Date()
        cachedHealthStatus = status
        
        return status
    }
    
    /// Load the model (pull if needed)
    func loadModel() async throws {
        modelStatus = .loading(progress: 0.0)
        
        // Check if model already exists
        if await isModelAvailable(defaultModel) {
            modelStatus = .loaded
            connectionStatus = .connected
            return
        }
        
        // Pull the model
        let progressStream = try await pullModel(defaultModel)
        
        for await progress in progressStream {
            if let total = progress.total, let completed = progress.completed, total > 0 {
                let percent = Double(completed) / Double(total)
                modelStatus = .loading(progress: percent)
            }
            
            if progress.status == "success" {
                modelStatus = .loaded
                connectionStatus = .connected
                break
            }
        }
    }
    
    /// Check if model is ready
    func checkModelReady() async -> Bool {
        return await isModelAvailable(defaultModel)
    }
    
    /// Cancel ongoing generation
    func cancelGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }
    
    // MARK: - Private Methods
    
    private func checkInitialStatus() async {
        connectionStatus = .connecting
        
        if await isOllamaRunning() {
            connectionStatus = .connected
            
            if await isModelAvailable(defaultModel) {
                modelStatus = .loaded
            } else {
                modelStatus = .notLoaded
            }
        } else {
            connectionStatus = .disconnected
            modelStatus = .notLoaded
        }
    }
    
    private func isOllamaRunning() async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/api/tags")!
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    private func isModelAvailable(_ model: String) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/api/tags")!
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(ModelsListResponse.self, from: data)
            return response.models.contains { $0.name == model || $0.name.hasPrefix(model) }
        } catch {
            return false
        }
    }
    
    private func startOllamaIfNeeded() async throws {
        // First check if Ollama is installed
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        checkProcess.arguments = ["ollama"]
        
        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        
        try checkProcess.run()
        checkProcess.waitUntilExit()
        
        guard checkProcess.terminationStatus == 0 else {
            throw OllamaError.notInstalled
        }
        
        // Try to start Ollama serve
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
        process.arguments = ["serve"]
        
        // Redirect output to avoid console spam
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        
        // Wait for server to start (max 10 seconds)
        for _ in 0..<20 {
            if await isOllamaRunning() {
                return
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        throw OllamaError.startupTimeout
    }
    
    private func pullModel(_ model: String) async throws -> AsyncStream<PullProgress> {
        return AsyncStream { continuation in
            Task {
                do {
                    let url = URL(string: "\(baseURL)/api/pull")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let body = ["name": model, "stream": true]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    
                    let (bytes, _) = try await session.bytes(for: request)
                    
                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8) else { continue }
                        
                        if let progress = try? JSONDecoder().decode(PullProgress.self, from: data) {
                            continuation.yield(progress)
                            
                            if progress.status == "success" {
                                continuation.finish()
                                return
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }
}

// MARK: - Ollama API Types

private struct OllamaRequest: Codable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
    let options: OllamaOptions?
    let keep_alive: String?
}

private struct OllamaMessage: Codable {
    let role: String
    let content: String
    let images: [String]?
}

private struct OllamaOptions: Codable {
    let temperature: Double?
    let top_k: Int?
    let top_p: Double?
    let num_predict: Int?
    let num_ctx: Int?
    let repeat_penalty: Double?
}

private struct OllamaStreamResponse: Codable {
    let model: String?
    let created_at: String?
    let message: OllamaMessage?
    let done: Bool
    let total_duration: Int64?
    let load_duration: Int64?
    let prompt_eval_count: Int?
    let prompt_eval_duration: Int64?
    let eval_count: Int?
    let eval_duration: Int64?
}

private struct OllamaErrorResponse: Codable {
    let error: String
}

private struct ModelsListResponse: Codable {
    let models: [ModelInfo]
}

private struct ModelInfo: Codable {
    let name: String
    let size: Int64?
    let digest: String?
}

private struct PullProgress: Codable {
    let status: String
    let digest: String?
    let total: Int64?
    let completed: Int64?
}

// MARK: - Errors

enum OllamaError: LocalizedError {
    case notInstalled
    case notRunning
    case modelNotFound(String)
    case httpError(Int)
    case apiError(String)
    case startupTimeout
    
    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Ollama is not installed. Please install it first."
        case .notRunning:
            return "Ollama server is not running"
        case .modelNotFound(let model):
            return "Model '\(model)' not found. It will be downloaded automatically."
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "Ollama API error: \(message)"
        case .startupTimeout:
            return "Ollama server failed to start"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notInstalled:
            return "Run 'brew install ollama' in Terminal, or let Gemi install it for you."
        case .notRunning:
            return "Gemi will start Ollama automatically."
        case .modelNotFound:
            return "The model will download on first use (about 7.5GB)."
        case .httpError:
            return "Check your network connection and try again."
        case .apiError:
            return "Please try your request again."
        case .startupTimeout:
            return "Try restarting the app or run 'ollama serve' manually."
        }
    }
}

// MARK: - Chat Protocol Conformance

@MainActor
protocol ChatServiceProtocol {
    func chat(_ request: OllamaChatService.ChatRequest) async throws -> AsyncThrowingStream<OllamaChatService.ChatResponse, Error>
    func health() async -> OllamaChatService.HealthStatus
    func cancelGeneration()
}

extension OllamaChatService: ChatServiceProtocol {}