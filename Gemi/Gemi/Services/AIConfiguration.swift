import Foundation

/// Configuration manager for AI model settings
@MainActor
final class AIConfiguration: ObservableObject {
    static let shared = AIConfiguration()
    
    // MARK: - Published Properties
    @Published var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: Keys.selectedModel)
        }
    }
    
    @Published var temperature: Double {
        didSet {
            UserDefaults.standard.set(temperature, forKey: Keys.temperature)
        }
    }
    
    @Published var maxTokens: Int {
        didSet {
            UserDefaults.standard.set(maxTokens, forKey: Keys.maxTokens)
        }
    }
    
    // MARK: - Constants
    private enum Keys {
        static let selectedModel = "com.gemi.ai.selectedModel"
        static let temperature = "com.gemi.ai.temperature"
        static let maxTokens = "com.gemi.ai.maxTokens"
    }
    
    private enum Defaults {
        static let selectedModel = "gemma3n:latest"
        static let temperature = 0.7
        static let maxTokens = 2048
    }
    
    // MARK: - Computed Properties
    var isMultimodalModel: Bool {
        // Gemma 3n is always multimodal
        return true
    }
    
    var estimatedMemoryUsage: Int64 {
        // Rough estimate for Ollama model
        return 4 * 1024 * 1024 * 1024 // 4GB for Gemma 3n
    }
    
    // MARK: - Initialization
    private init() {
        // Initialize all properties first with defaults
        self.selectedModel = UserDefaults.standard.string(forKey: Keys.selectedModel) ?? Defaults.selectedModel
        
        let storedTemperature = UserDefaults.standard.double(forKey: Keys.temperature)
        self.temperature = storedTemperature == 0 ? Defaults.temperature : storedTemperature
        
        let storedMaxTokens = UserDefaults.standard.integer(forKey: Keys.maxTokens)
        self.maxTokens = storedMaxTokens == 0 ? Defaults.maxTokens : storedMaxTokens
    }
    
    // MARK: - Methods
    func resetToDefaults() {
        selectedModel = Defaults.selectedModel
        temperature = Defaults.temperature
        maxTokens = Defaults.maxTokens
    }
    
    /// Check if model is ready
    func isModelReady() async -> Bool {
        let health = await OllamaChatService.shared.health()
        return health.modelLoaded
    }
    
    /// Get available models
    func getAvailableModels() -> [String] {
        // Return Ollama models
        return ["gemma3n:latest", "gemma3n:e2b", "gemma3n:e4b"]
    }
}

