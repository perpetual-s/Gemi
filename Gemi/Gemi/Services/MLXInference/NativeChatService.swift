import Foundation
import Combine

/// Native chat service using MLX for inference (replaces server-based implementation)
@MainActor
final class NativeChatService: ObservableObject {
    static let shared = NativeChatService()
    
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
    
    // MARK: - Properties
    
    private let model = GemmaMLXModel()
    private let modelDownloader = ModelDownloader()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupBindings()
        Task {
            await checkModelStatus()
        }
    }
    
    // MARK: - Public Methods
    
    /// Send a chat request with streaming response
    func chat(_ request: ChatRequest) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        // Ensure model is loaded
        if case .notLoaded = modelStatus {
            try await loadModel()
        }
        
        guard case .loaded = modelStatus else {
            throw ChatError.modelNotReady
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    isGenerating = true
                    
                    // Convert messages to prompt
                    let prompt = formatPrompt(from: request.messages)
                    
                    // Extract images if present
                    let images = try extractImages(from: request.messages)
                    
                    // Configure generation
                    let config = GemmaMLXModel.GenerationConfig(
                        maxTokens: request.options?.maxTokens ?? 2048,
                        temperature: request.options?.temperature ?? 0.7,
                        topK: request.options?.topK ?? 50,
                        topP: request.options?.topP ?? 0.95,
                        repetitionPenalty: 1.1
                    )
                    
                    // Generate response
                    var responseText = ""
                    let startTime = Date()
                    var tokenCount = 0
                    
                    for await token in model.generate(prompt: prompt, images: images, config: config) {
                        responseText += token
                        tokenCount += 1
                        
                        if request.stream {
                            // Stream each token as a response
                            let response = ChatResponse(
                                message: ChatMessage(role: "assistant", content: token, images: nil),
                                done: false,
                                totalDuration: nil,
                                loadDuration: nil,
                                promptEvalCount: nil,
                                evalCount: tokenCount,
                                evalDuration: Int64(Date().timeIntervalSince(startTime) * 1_000_000_000)
                            )
                            continuation.yield(response)
                        }
                    }
                    
                    // Send final response
                    let finalResponse = ChatResponse(
                        message: ChatMessage(role: "assistant", content: responseText, images: nil),
                        done: true,
                        totalDuration: Int64(Date().timeIntervalSince(startTime) * 1_000_000_000),
                        loadDuration: 0,
                        promptEvalCount: prompt.count, // Approximate
                        evalCount: tokenCount,
                        evalDuration: Int64(Date().timeIntervalSince(startTime) * 1_000_000_000)
                    )
                    
                    continuation.yield(finalResponse)
                    continuation.finish()
                    
                    isGenerating = false
                    
                } catch {
                    isGenerating = false
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Get health status
    func health() async -> HealthStatus {
        return HealthStatus(
            healthy: modelStatus == .loaded,
            modelLoaded: model.isLoaded,
            device: "mps" // Metal Performance Shaders
        )
    }
    
    /// Load the model
    func loadModel() async throws {
        guard !model.isLoaded else { return }
        
        modelStatus = .loading(progress: 0.0)
        
        do {
            try await model.loadModel()
            modelStatus = .loaded
            connectionStatus = .connected
        } catch {
            modelStatus = .error(error.localizedDescription)
            connectionStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    /// Download the model if needed
    func downloadModelIfNeeded() async throws {
        let isComplete = await ModelCache.shared.isModelComplete()
        guard !isComplete else {
            return
        }
        
        try await modelDownloader.startDownload()
    }
    
    /// Cancel ongoing generation
    func cancelGeneration() {
        model.cancelGeneration()
        isGenerating = false
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind model loading progress
        model.$loadProgress
            .sink { [weak self] progress in
                if progress > 0 && progress < 1 {
                    self?.modelStatus = .loading(progress: progress)
                }
            }
            .store(in: &cancellables)
        
        // Bind model loaded state
        model.$isLoaded
            .sink { [weak self] isLoaded in
                if isLoaded {
                    self?.modelStatus = .loaded
                    self?.connectionStatus = .connected
                }
            }
            .store(in: &cancellables)
        
        // Bind downloader state
        modelDownloader.$downloadState
            .sink { [weak self] state in
                switch state {
                case .downloading(_, let progress):
                    self?.modelStatus = .loading(progress: progress * 0.5) // First 50% is download
                case .completed:
                    Task {
                        try? await self?.loadModel()
                    }
                case .failed(let error):
                    self?.modelStatus = .error(error)
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkModelStatus() async {
        if await ModelCache.shared.isModelComplete() {
            // Model files exist, try to load
            do {
                try await loadModel()
            } catch {
                modelStatus = .error(error.localizedDescription)
            }
        } else {
            modelStatus = .notLoaded
            connectionStatus = .disconnected
        }
    }
    
    private func formatPrompt(from messages: [ChatMessage]) -> String {
        // Format messages into a prompt for Gemma 3n
        // This follows the expected format for the model
        
        var prompt = ""
        
        for message in messages {
            switch message.role {
            case "system":
                prompt += "<system>\n\(message.content)\n</system>\n\n"
            case "user":
                prompt += "<user>\n\(message.content)\n</user>\n\n"
            case "assistant":
                prompt += "<assistant>\n\(message.content)\n</assistant>\n\n"
            default:
                prompt += "\(message.content)\n\n"
            }
        }
        
        // Add assistant prompt to trigger generation
        prompt += "<assistant>\n"
        
        return prompt
    }
    
    private func extractImages(from messages: [ChatMessage]) throws -> [Data]? {
        var images: [Data] = []
        
        for message in messages {
            guard let base64Images = message.images else { continue }
            
            for base64String in base64Images {
                // Remove data URL prefix if present
                let base64 = base64String
                    .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                    .replacingOccurrences(of: "data:image/png;base64,", with: "")
                
                guard let imageData = Data(base64Encoded: base64) else {
                    throw ChatError.invalidImageData
                }
                
                images.append(imageData)
            }
        }
        
        return images.isEmpty ? nil : images
    }
}

// MARK: - Chat Protocol Conformance

@MainActor
protocol ChatServiceProtocol {
    func chat(_ request: NativeChatService.ChatRequest) async throws -> AsyncThrowingStream<NativeChatService.ChatResponse, Error>
    func health() async -> NativeChatService.HealthStatus
    func cancelGeneration()
}

extension NativeChatService: ChatServiceProtocol {}

// MARK: - Errors

enum ChatError: LocalizedError {
    case modelNotReady
    case invalidImageData
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotReady:
            return "Model is not loaded"
        case .invalidImageData:
            return "Invalid image data provided"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        }
    }
}