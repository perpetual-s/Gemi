import Foundation
import Combine
import MLX
import MLXNN
import MLXFast
import MLXRandom

/// MLX-based Gemma 3n model for multimodal inference
@MainActor
final class GemmaMLXModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isLoaded = false
    @Published var isGenerating = false
    @Published var loadProgress: Double = 0.0
    @Published var error: Error?
    
    // MARK: - Properties
    
    private let modelCache = ModelCache.shared
    private var model: GemmaModel? // MLX model
    private var tokenizer: GemmaTokenizer?
    private var config: ModelConfig?
    
    private let maxContextLength = 32768
    private let device = Device.gpu // Metal Performance Shaders
    
    // MARK: - Types
    
    struct GenerationConfig {
        let maxTokens: Int
        let temperature: Double
        let topK: Int
        let topP: Double
        let repetitionPenalty: Double
        
        static let `default` = GenerationConfig(
            maxTokens: 2048,
            temperature: 0.7,
            topK: 50,
            topP: 0.95,
            repetitionPenalty: 1.1
        )
    }
    
    struct GenerationResult {
        let text: String
        let tokensGenerated: Int
        let timeElapsed: TimeInterval
    }
    
    // MARK: - Initialization
    
    init() {
        // No initialization needed
    }
    
    // MARK: - Public Methods
    
    /// Load the model from disk
    func loadModel() async throws {
        guard !isLoaded else { return }
        
        // Check if model files exist
        guard await modelCache.isModelComplete() else {
            throw ModelError.modelNotFound
        }
        
        loadProgress = 0.1
        
        do {
            // Load configuration
            let configPath = modelCache.modelPath.appendingPathComponent("config.json")
            
            // Check if config file exists
            guard FileManager.default.fileExists(atPath: configPath.path) else {
                throw ModelError.modelNotFound
            }
            
            let configData = try Data(contentsOf: configPath)
            
            // Try to decode the config with better error handling
            do {
                self.config = try JSONDecoder().decode(ModelConfig.self, from: configData)
            } catch let decodingError {
                // Print the actual JSON for debugging
                if let jsonString = String(data: configData, encoding: .utf8) {
                    print("⚠️ Failed to decode config.json")
                    
                    // Try to parse as generic JSON to see what fields exist
                    if let json = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
                        print("📋 Available fields in config.json:")
                        for (key, value) in json.sorted(by: { $0.key < $1.key }) {
                            let valueType = type(of: value)
                            print("  - \(key): \(valueType)")
                        }
                        
                        // Print specific values that might help
                        print("\n📊 Key values:")
                        if let modelType = json["model_type"] { print("  - model_type: \(modelType)") }
                        if let vocabSize = json["vocab_size"] { print("  - vocab_size: \(vocabSize)") }
                        if let layers = json["num_hidden_layers"] { print("  - num_hidden_layers: \(layers)") }
                        if let layers = json["layers"] { print("  - layers: \(layers)") }
                        if let hidden = json["hidden_size"] { print("  - hidden_size: \(hidden)") }
                        if let heads = json["num_attention_heads"] { print("  - num_attention_heads: \(heads)") }
                    }
                }
                print("\n❌ Decoding error: \(decodingError)")
                
                // Try to provide more helpful error message
                if let decodingError = decodingError as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                        throw ModelError.downloadFailed("""
                            Missing field '\(key.stringValue)' in config.json
                            
                            This may indicate:
                            1. The model config format has changed
                            2. The download was incomplete
                            
                            Try deleting the model folder and downloading again.
                            Path: \(path.isEmpty ? "root" : path)
                            """)
                    case .typeMismatch(let type, let context):
                        throw ModelError.downloadFailed("Type mismatch for field at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). Expected \(type)")
                    case .dataCorrupted(let context):
                        throw ModelError.downloadFailed("Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    default:
                        throw ModelError.downloadFailed("Failed to decode config.json: \(decodingError.localizedDescription)")
                    }
                } else {
                    throw ModelError.downloadFailed("Failed to decode config.json: \(decodingError.localizedDescription)")
                }
            }
            
            loadProgress = 0.2
            
            // Initialize model architecture
            guard let config = self.config else {
                throw ModelError.invalidConfiguration
            }
            
            self.model = try await createGemmaModel(config: config)
            
            loadProgress = 0.5
            
            // Load weights from safetensors files
            try await loadSafetensors()
            
            loadProgress = 0.8
            
            // Initialize tokenizer
            self.tokenizer = try await GemmaTokenizer(modelPath: modelCache.modelPath)
            
            loadProgress = 0.9
            
            // Model is ready
            loadProgress = 1.0
            isLoaded = true
            
        } catch {
            self.error = error
            
            // Run diagnostics when loading fails
            print("\n⚠️ Model loading failed. Running diagnostics...")
            ModelDiagnostics.diagnoseModelFiles()
            
            // Run authentication test if it seems like an auth issue
            if let modelError = error as? ModelError {
                switch modelError {
                case .authenticationRequired:
                    await ModelDiagnostics.testHuggingFaceAuthentication()
                default:
                    break
                }
            }
            
            throw error
        }
    }
    
    /// Generate text from a prompt
    func generate(prompt: String, images: [Data]? = nil, config: GenerationConfig = .default) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                do {
                    guard isLoaded else {
                        throw ModelError.modelNotLoaded
                    }
                    
                    guard let model = self.model,
                          let tokenizer = self.tokenizer else {
                        throw ModelError.modelNotLoaded
                    }
                    
                    isGenerating = true
                    
                    // Process images if provided
                    var imageEmbeddings: [MLXArray]? = nil
                    if let images = images {
                        let processedImages = try await processImages(images)
                        imageEmbeddings = processedImages.compactMap { $0.preprocessedTensor }
                    }
                    
                    // Tokenize input
                    let inputTokens = tokenizer.encode(prompt)
                    var tokens = inputTokens
                    
                    // TODO: For full multimodal support, we need to:
                    // 1. Pass image embeddings through vision encoder
                    // 2. Concatenate with text embeddings
                    // 3. Use cross-attention in transformer layers
                    // This requires the full Gemma 3n architecture
                    
                    // Generate tokens
                    for _ in 0..<config.maxTokens {
                        // Create input tensor
                        let inputArray = MLXArray(tokens.map { Int32($0) })
                        
                        // Forward pass through model
                        let logits = model(inputArray)
                        
                        // Sample next token
                        let nextToken = sampleToken(
                            logits: logits,
                            temperature: Float(config.temperature),
                            topK: config.topK
                        )
                        
                        // Check for end token
                        if tokenizer.isEndToken(nextToken) {
                            break
                        }
                        
                        tokens.append(nextToken)
                        
                        // Decode and yield token
                        let text = tokenizer.decode([nextToken])
                        continuation.yield(text)
                        
                        // Check for cancellation
                        if Task.isCancelled || !isGenerating {
                            break
                        }
                    }
                    
                    isGenerating = false
                    continuation.finish()
                    
                } catch {
                    self.error = error
                    isGenerating = false
                    continuation.finish()
                }
            }
        }
    }
    
    /// Cancel ongoing generation
    func cancelGeneration() {
        isGenerating = false
    }
    
    /// Unload model to free memory
    func unloadModel() {
        model = nil
        tokenizer = nil
        isLoaded = false
        loadProgress = 0.0
    }
    
    // MARK: - Private Methods
    
    private func createGemmaModel(config: ModelConfig) async throws -> GemmaModel {
        return GemmaModel(config: config)
    }
    
    private func loadSafetensors() async throws {
        // Load safetensors weights
        let weightFiles = [
            "model-00001-of-00004.safetensors",
            "model-00002-of-00004.safetensors",
            "model-00003-of-00004.safetensors",
            "model-00004-of-00004.safetensors"
        ]
        
        guard let model = self.model else { return }
        
        // Load all weight files
        let weights = try await SafetensorsLoader.loadModelWeights(
            from: modelCache.modelPath,
            fileNames: weightFiles
        )
        
        // Apply weights to model
        // For now, we'll just load the attention weights since they're accessible
        
        // Load transformer layer weights
        for (layerIdx, layer) in model.layers.enumerated() {
            let prefix = "model.layers.\(layerIdx)"
            
            // Attention weights (these are accessible via our custom GemmaAttention)
            if let qWeight = weights["\(prefix).self_attn.q_proj.weight"] {
                layer.selfAttention.wq = qWeight
            }
            if let kWeight = weights["\(prefix).self_attn.k_proj.weight"] {
                layer.selfAttention.wk = kWeight
            }
            if let vWeight = weights["\(prefix).self_attn.v_proj.weight"] {
                layer.selfAttention.wv = vWeight
            }
            if let oWeight = weights["\(prefix).self_attn.o_proj.weight"] {
                layer.selfAttention.wo = oWeight
            }
            
            // MLP weights (these are accessible via our custom MLP)
            if let gateWeight = weights["\(prefix).mlp.gate_proj.weight"] {
                layer.mlp.gateWeight = gateWeight
            }
            if let upWeight = weights["\(prefix).mlp.up_proj.weight"] {
                layer.mlp.upWeight = upWeight
            }
            if let downWeight = weights["\(prefix).mlp.down_proj.weight"] {
                layer.mlp.downWeight = downWeight
            }
            
            // Update progress
            loadProgress = 0.5 + (0.4 * Double(layerIdx + 1) / Double(model.layers.count))
        }
        
        // TODO: In production, we need to either:
        // 1. Create custom layers with mutable weights
        // 2. Store weights separately and apply during forward pass
        // 3. Use MLX's built-in model loading once available
        
        loadProgress = 0.95
    }
    
    private func prepareInput(prompt: String, images: [Data]?) async throws -> ModelInput {
        var input = ModelInput(text: prompt)
        
        if let images = images {
            // Process images for multimodal input
            input.images = try await processImages(images)
        }
        
        return input
    }
    
    private func processImages(_ imagesData: [Data]) async throws -> [ProcessedImage] {
        var processedImages: [ProcessedImage] = []
        
        for imageData in imagesData {
            // Process image using GemmaImageProcessor
            let processed = try await ProcessedImage.create(from: imageData)
            processedImages.append(processed)
        }
        
        return processedImages
    }
    
    private func sampleToken(logits: MLXArray, temperature: Float, topK: Int) -> Int {
        // Apply temperature
        let scaledLogits = logits / temperature
        
        // For now, use argmax (greedy sampling)
        // TODO: Implement proper top-k sampling when MLX.topK is available
        let maxIndex = argMax(scaledLogits, axis: -1)
        
        return Int(maxIndex.item(Int32.self))
    }
}

// MARK: - Supporting Types

struct ModelConfig: Codable {
    let modelType: String
    let vocabSize: Int
    
    // These fields might have different names in different model configs
    let numLayers: Int?
    let hiddenSize: Int?
    let numHeads: Int?
    
    // Optional fields
    let intermediateSize: Int?
    let numKeyValueHeads: Int?
    let headDim: Int?
    let maxPositionEmbeddings: Int?
    let rmsNormEps: Double?
    let ropeTheta: Double?
    let attentionBias: Bool?
    let attentionDropout: Double?
    let mlpBias: Bool?
    
    // Alternative field names that Gemma might use
    let layers: Int?
    let dModel: Int?
    let nHeads: Int?
    let dim: Int?
    
    private enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case numLayers = "num_hidden_layers"
        case hiddenSize = "hidden_size"
        case numHeads = "num_attention_heads"
        case vocabSize = "vocab_size"
        case intermediateSize = "intermediate_size"
        case numKeyValueHeads = "num_key_value_heads"
        case headDim = "head_dim"
        case maxPositionEmbeddings = "max_position_embeddings"
        case rmsNormEps = "rms_norm_eps"
        case ropeTheta = "rope_theta"
        case attentionBias = "attention_bias"
        case attentionDropout = "attention_dropout"
        case mlpBias = "mlp_bias"
        
        // Alternative field names
        case layers = "layers"
        case dModel = "d_model"
        case nHeads = "n_heads"
        case dim = "dim"
    }
    
    // Computed properties to handle different field names
    var actualNumLayers: Int {
        return numLayers ?? layers ?? 32 // Default for Gemma 3n
    }
    
    var actualHiddenSize: Int {
        return hiddenSize ?? dModel ?? dim ?? 4096 // Default for Gemma 3n
    }
    
    var actualNumHeads: Int {
        return numHeads ?? nHeads ?? 32 // Default for Gemma 3n
    }
}

struct ModelInput {
    var text: String
    var images: [ProcessedImage]?
}

struct ProcessedImage {
    let data: Data
    var tensor: MLXArray?
    var preprocessedTensor: MLXArray?
}

// MARK: - Errors

extension ModelError {
    static let modelNotLoaded = ModelError.downloadFailed("Model not loaded")
    static let invalidConfiguration = ModelError.downloadFailed("Invalid model configuration")
}

// MARK: - Helper Components

/// Custom attention for Gemma with accessible weights
class GemmaAttention: Module {
    var wq: MLXArray?
    var wk: MLXArray?
    var wv: MLXArray?
    var wo: MLXArray?
    
    let dimensions: Int
    let numHeads: Int
    let headDim: Int
    
    init(dimensions: Int, numHeads: Int) {
        self.dimensions = dimensions
        self.numHeads = numHeads
        self.headDim = dimensions / numHeads
        super.init()
    }
    
    func callAsFunction(_ x: MLXArray) -> MLXArray {
        // Apply projections
        let q = matmul(x, wq ?? MLXArray.zeros([dimensions, dimensions]))
        let k = matmul(x, wk ?? MLXArray.zeros([dimensions, dimensions]))
        let v = matmul(x, wv ?? MLXArray.zeros([dimensions, dimensions]))
        
        // Reshape for multi-head attention
        let batchSize = x.shape[0]
        let seqLen = x.shape[1]
        
        let qHeads = q.reshaped([batchSize, seqLen, numHeads, headDim]).transposed(0, 2, 1, 3)
        let kHeads = k.reshaped([batchSize, seqLen, numHeads, headDim]).transposed(0, 2, 1, 3)
        let vHeads = v.reshaped([batchSize, seqLen, numHeads, headDim]).transposed(0, 2, 1, 3)
        
        // Scaled dot-product attention
        let scale = 1.0 / sqrt(Float(headDim))
        let scores = matmul(qHeads, kHeads.transposed(0, 1, 3, 2)) * scale
        let weights = softmax(scores, axis: -1)
        let attention = matmul(weights, vHeads)
        
        // Reshape back
        let concatAttention = attention.transposed(0, 2, 1, 3).reshaped([batchSize, seqLen, dimensions])
        
        // Output projection
        return matmul(concatAttention, wo ?? MLXArray.zeros([dimensions, dimensions]))
    }
}

/// Simplified Gemma model for MLX
class GemmaModel: Module {
    let embedding: Embedding
    let layers: [TransformerLayer]
    let outputProjection: Linear
    let norm: RMSNorm
    
    init(config: ModelConfig) {
        self.embedding = Embedding(
            embeddingCount: config.vocabSize,
            dimensions: config.actualHiddenSize
        )
        
        self.layers = (0..<config.actualNumLayers).map { _ in
            TransformerLayer(
                dimensions: config.actualHiddenSize,
                numHeads: config.actualNumHeads
            )
        }
        
        self.norm = RMSNorm(dimensions: config.actualHiddenSize)
        self.outputProjection = Linear(config.actualHiddenSize, config.vocabSize)
        
        super.init()
    }
    
    func callAsFunction(_ tokens: MLXArray) -> MLXArray {
        // Token embeddings
        var x = embedding(tokens)
        
        // Pass through transformer layers
        for layer in layers {
            x = layer(x)
        }
        
        // Final norm and projection
        x = norm(x)
        return outputProjection(x)
    }
}

/// Transformer layer for Gemma
class TransformerLayer: Module {
    let selfAttention: GemmaAttention
    let mlp: MLP
    let inputLayerNorm: RMSNorm
    let postAttentionLayerNorm: RMSNorm
    
    init(dimensions: Int, numHeads: Int) {
        self.selfAttention = GemmaAttention(
            dimensions: dimensions,
            numHeads: numHeads
        )
        
        self.mlp = MLP(
            dimensions: dimensions,
            hiddenDimensions: dimensions * 4
        )
        
        self.inputLayerNorm = RMSNorm(dimensions: dimensions)
        self.postAttentionLayerNorm = RMSNorm(dimensions: dimensions)
        
        super.init()
    }
    
    func callAsFunction(_ x: MLXArray) -> MLXArray {
        // Pre-norm residual architecture
        let normed = inputLayerNorm(x)
        let attnOut = selfAttention(normed)
        var h = x + attnOut
        
        let normed2 = postAttentionLayerNorm(h)
        let mlpOut = mlp(normed2)
        h = h + mlpOut
        
        return h
    }
}

/// MLP layer
class MLP: Module {
    var gateWeight: MLXArray?
    var upWeight: MLXArray?
    var downWeight: MLXArray?
    
    let dimensions: Int
    let hiddenDimensions: Int
    
    init(dimensions: Int, hiddenDimensions: Int) {
        self.dimensions = dimensions
        self.hiddenDimensions = hiddenDimensions
        super.init()
    }
    
    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let gateW = gateWeight ?? MLXArray.zeros([dimensions, hiddenDimensions])
        let upW = upWeight ?? MLXArray.zeros([dimensions, hiddenDimensions])
        let downW = downWeight ?? MLXArray.zeros([hiddenDimensions, dimensions])
        
        let gate = matmul(x, gateW)
        let up = matmul(x, upW)
        let activated = silu(gate) * up
        return matmul(activated, downW)
    }
}


// MARK: - Memory Management

extension GemmaMLXModel {
    /// Get current memory usage
    func getMemoryUsage() -> Int64 {
        // Placeholder - would use actual memory profiling
        return isLoaded ? 4_294_967_296 : 0 // 4GB when loaded
    }
    
    /// Handle memory pressure
    func handleMemoryPressure() {
        if !isGenerating {
            // Could unload less critical components
            // or reduce precision temporarily
        }
    }
}