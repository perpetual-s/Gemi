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
        static let temperature = 1.0  // Optimal for Gemma 3n creative writing
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
    
    /// Get optimized temperature based on conversation context
    /// Using Gemma 3n optimal settings: base 1.0 with contextual adjustments
    func getContextualTemperature(for messageContent: String) -> Double {
        let lowercased = messageContent.lowercased()
        
        // Check if this is a writing assistance request
        if lowercased.contains("continue") || lowercased.contains("ideas") ||
           lowercased.contains("improve") || lowercased.contains("suggest") {
            // Writing assistance contexts - use optimal Gemma 3n creative temperature
            if lowercased.contains("continue writing") || lowercased.contains("what happens next") {
                return 0.7  // Continuation: coherent flow
            } else if lowercased.contains("ideas") || lowercased.contains("explore") {
                return 0.8  // Ideation: creative exploration
            } else if lowercased.contains("improve") || lowercased.contains("style") {
                return 0.3  // Style improvement: precision
            } else if lowercased.contains("emotion") || lowercased.contains("feeling") {
                return 0.6  // Emotional exploration: balanced
            } else if lowercased.contains("stuck") || lowercased.contains("block") {
                return 0.9  // Writer's block: high creativity
            }
        }
        
        // Creative writing or storytelling - Gemma 3n sweet spot
        if lowercased.contains("story") || lowercased.contains("imagine") || 
           lowercased.contains("dream") || lowercased.contains("creative") {
            return 1.0  // Optimal for Gemma 3n creative tasks
        }
        
        // Emotional processing - slightly lower for coherence
        if lowercased.contains("feel") || lowercased.contains("emotion") ||
           lowercased.contains("sad") || lowercased.contains("happy") ||
           lowercased.contains("angry") || lowercased.contains("anxious") {
            return 0.8
        }
        
        // Seeking advice or clarity - lower temperature for accuracy
        if lowercased.contains("advice") || lowercased.contains("should i") ||
           lowercased.contains("what do you think") || lowercased.contains("help me understand") {
            return 0.5
        }
        
        // Default to Gemma 3n optimal temperature
        return 1.0
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

