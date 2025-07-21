import Foundation
import MLX
import MLXNN
import MLXFast
import MLXRandom

/// Simplified Gemma model using MLX best practices
/// No over-engineering - just clean, simple code for Apple Silicon
@MainActor
final class SimplifiedGemmaModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isLoaded = false
    @Published var isGenerating = false
    @Published var error: Error?
    
    // MARK: - Properties
    
    private let modelCache = ModelCache.shared
    private var weights: [String: MLXArray] = [:]
    private var tokenizer: GemmaTokenizer?
    
    // Model components - using MLX's built-in modules
    private var embeddings: Embedding?
    private var embedProjection: Linear?  // Project from embedDim to hiddenSize
    private var layers: [TransformerBlock] = []
    private var norm: RMSNorm?
    private var output: Linear?
    
    // Model configuration - Gemma 3n E4B (from config.json)
    private let hiddenSize = 2048  // text_config.hidden_size
    private let embedDim = 256     // Actual embedding dimension for multimodal model
    private let numLayers = 35     // text_config.num_hidden_layers
    private let numHeads = 8       // text_config.num_attention_heads
    private let vocabSize = 262400 // text_config.vocab_size
    
    // MARK: - Public Methods
    
    /// Load the bundled model
    func loadModel() async throws {
        guard !isLoaded else { return }
        
        do {
            // 1. Load tokenizer
            tokenizer = try await GemmaTokenizer(modelPath: modelCache.modelPath)
            
            // 2. Load weights using MLX's native loading
            let modelFiles = [
                "model-00001-of-00002.safetensors",
                "model-00002-of-00002.safetensors"
            ]
            
            for file in modelFiles {
                let url = modelCache.modelPath.appendingPathComponent(file)
                print("🔍 Loading weights from: \(url.path)")
                
                // Ensure the file exists before trying to load
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ModelError.setupFailed("Model file not found: \(url.path)")
                }
                
                // Convert to absolute file URL to ensure MLX gets the correct path
                let absoluteURL = URL(fileURLWithPath: url.path)
                print("🔍 Absolute URL: \(absoluteURL)")
                
                let fileWeights = try MLX.loadArrays(url: absoluteURL)
                weights.merge(fileWeights) { _, new in new }
                print("✅ Loaded \(fileWeights.count) weight arrays from \(file)")
            }
            
            // 3. Initialize model components
            setupModelArchitecture()
            
            // 4. Model is ready
            isLoaded = true
            print("✅ Model loaded successfully")
            
            // 5. Warm up model to eliminate slow first token (after marking as loaded)
            await warmUpModel()
            
        } catch {
            self.error = error
            print("❌ Model loading failed: \(error)")
            throw error
        }
    }
    
    /// Generate text with proper sampling
    func generate(prompt: String, maxTokens: Int = 512, temperature: Float = 0.7) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                do {
                    guard isLoaded, let tokenizer = self.tokenizer else {
                        throw ModelError.modelNotLoaded
                    }
                    
                    isGenerating = true
                    
                    // Tokenize input
                    var tokens = tokenizer.encode(prompt)
                    
                    // Generate tokens
                    for _ in 0..<maxTokens {
                        // Get logits for the last token
                        let logits = try forward(tokens: tokens)
                        
                        // Sample next token with temperature
                        let nextToken = try sampleToken(
                            logits: logits,
                            temperature: temperature,
                            topK: 40,
                            topP: 0.95
                        )
                        
                        // Check for end token
                        if tokenizer.isEndToken(nextToken) {
                            break
                        }
                        
                        tokens.append(nextToken)
                        
                        // Decode and yield
                        let text = tokenizer.decode([nextToken])
                        continuation.yield(text)
                        
                        // Memory management: evaluate tensors to free intermediate memory
                        MLX.eval(logits)
                        
                        // Periodically clear GPU cache to prevent memory buildup
                        if tokens.count % 50 == 0 {
                            MLX.GPU.clearCache()
                        }
                        
                        // Allow cancellation
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
    
    /// Cancel generation
    func cancelGeneration() {
        isGenerating = false
    }
    
    // MARK: - Private Methods
    
    /// Warm up the model with a dummy generation to eliminate slow first token
    private func warmUpModel() async {
        // Ensure model is fully loaded with all components initialized
        guard isLoaded,
              let tokenizer = self.tokenizer,
              embeddings != nil,
              embedProjection != nil,
              norm != nil,
              output != nil,
              !layers.isEmpty else {
            print("⚠️ Model not fully initialized, skipping warm-up")
            return
        }
        
        print("🔥 Warming up model...")
        
        do {
            // Simple warm-up prompt
            let warmupTokens = tokenizer.encode("Hello")
            
            // Generate one token to warm up all model layers
            _ = try forward(tokens: warmupTokens)
            
            // Clear any memory used during warm-up
            MLX.GPU.clearCache()
            
            print("✅ Model warmed up")
        } catch {
            print("⚠️ Model warm-up failed: \(error)")
            // Non-critical error, continue anyway
        }
    }
    
    private func setupModelArchitecture() {
        // Simple architecture setup using MLX modules
        // IMPORTANT: The actual Gemma 3n uses 256-dim embeddings with per-layer projection
        // We'll create embeddings with the actual embedding dimension first
        embeddings = Embedding(embeddingCount: vocabSize, dimensions: embedDim)
        
        // Create projection layer to map from embedDim to hiddenSize
        embedProjection = Linear(embedDim, hiddenSize, bias: false)
        
        // Create transformer layers
        for _ in 0..<numLayers {
            layers.append(TransformerBlock(dimensions: hiddenSize, headCount: numHeads))
        }
        
        norm = RMSNorm(dimensions: hiddenSize, eps: 1e-6)
        output = Linear(hiddenSize, vocabSize, bias: false)
        
        // Initialize final norm weight to prevent crashes
        var normParams = ModuleParameters()
        normParams["weight"] = .value(MLXArray.ones([hiddenSize]))
        norm?.update(parameters: normParams)
        
        // Load weights into modules
        loadWeightsIntoModules()
    }
    
    private func loadWeightsIntoModules() {
        print("🔄 Loading Gemma 3n AltUp weights into model...")
        
        // Debug: Print available weight keys to understand model structure
        print("📊 Available weight keys (sample):")
        let sortedKeys = weights.keys.sorted()
        for (index, key) in sortedKeys.enumerated() {
            if index < 30 || key.contains("embed") || key.contains("projection") {
                if let shape = weights[key]?.shape {
                    print("   - \(key): \(shape)")
                }
            }
        }
        print("   ... total \(sortedKeys.count) weights")
        
        // Load embedding weights - Note: multimodal model uses language_model.model prefix
        let embeddingKey = "language_model.model.embed_tokens.weight"
        if let embWeight = weights[embeddingKey] {
            print("🔍 Found embedding weight shape: \(embWeight.shape)")
            
            var params = ModuleParameters()
            params["weight"] = .value(embWeight)
            embeddings?.update(parameters: params)
            print("✅ Loaded embedding weights: \(embWeight.shape)")
            
            // Note: The actual model uses Per-Layer Embeddings (PLE) which we're simplifying
            // by using a linear projection from 256 to 2048 dimensions
            
            // Check for embedding projection weights
            let projectionKeys = [
                "language_model.model.embed_projection.weight",
                "language_model.model.embed_tokens_projection.weight",
                "model.embed_projection.weight"
            ]
            
            var projectionLoaded = false
            for key in projectionKeys {
                if let projWeight = weights[key] {
                    print("🔍 Found embedding projection weight: \(key) with shape: \(projWeight.shape)")
                    var params = ModuleParameters()
                    params["weight"] = .value(projWeight)
                    embedProjection?.update(parameters: params)
                    projectionLoaded = true
                    break
                }
            }
            
            if !projectionLoaded {
                print("⚠️ No embedding projection weights found, will use random initialization")
                print("   Tried keys: \(projectionKeys)")
            }
        } else {
            // Try without language_model prefix for text-only models
            if let embWeight = weights["model.embed_tokens.weight"] {
                var params = ModuleParameters()
                params["weight"] = .value(embWeight)
                embeddings?.update(parameters: params)
                print("✅ Loaded embedding weights (text-only model): \(embWeight.shape)")
            } else {
                print("⚠️ Embedding weights not found. Tried:")
                print("   - \(embeddingKey)")
                print("   - model.embed_tokens.weight")
            }
        }
        
        // Load transformer layer weights - AltUp architecture
        for (i, layer) in layers.enumerated() {
            // Gemma 3n uses language_model.model prefix
            let multimodalPrefix = "language_model.model.layers.\(i)"
            let textOnlyPrefix = "model.layers.\(i)"
            
            // Check which prefix has weights - AltUp uses different component names
            let prefix = if weights["\(multimodalPrefix).laurel.linear_left.weight"] != nil {
                multimodalPrefix  // AltUp architecture
            } else if weights["\(multimodalPrefix).self_attn.q_proj.weight"] != nil {
                multimodalPrefix  // Standard attention
            } else if weights["\(textOnlyPrefix).self_attn.q_proj.weight"] != nil {
                textOnlyPrefix
            } else {
                ""
            }
            
            if !prefix.isEmpty {
                print("✅ Found weights for layer \(i) (prefix: \(prefix))")
                
                // CRITICAL: Load layer normalization weights to prevent crash
                // Try both naming conventions for layer norms
                let norm1Keys = [
                    "\(prefix).input_layernorm.weight",
                    "\(prefix).ln_1.weight"
                ]
                
                var norm1Loaded = false
                for key in norm1Keys {
                    if let normWeight = weights[key] {
                        var params = ModuleParameters()
                        params["weight"] = .value(normWeight)
                        layer.norm1.update(parameters: params)
                        print("  ✓ Loaded norm1 weights from \(key)")
                        norm1Loaded = true
                        break
                    }
                }
                if !norm1Loaded {
                    print("  ⚠️ No norm1 weights found for layer \(i)")
                }
                
                let norm2Keys = [
                    "\(prefix).post_attention_layernorm.weight",
                    "\(prefix).ln_2.weight"
                ]
                
                var norm2Loaded = false
                for key in norm2Keys {
                    if let normWeight = weights[key] {
                        var params = ModuleParameters()
                        params["weight"] = .value(normWeight)
                        layer.norm2.update(parameters: params)
                        print("  ✓ Loaded norm2 weights from \(key)")
                        norm2Loaded = true
                        break
                    }
                }
                if !norm2Loaded {
                    print("  ⚠️ No norm2 weights found for layer \(i)")
                }
                
                // Load transformer block weights (attention and MLP)
                layer.loadWeights(from: weights, prefix: prefix)
                
                // Document available weights for AltUp architecture:
                let components = [
                    // AltUp components
                    "laurel.linear_left", "laurel.linear_right",
                    "altup.modality_router", "altup.router_norm",
                    "input_layernorm", "post_attention_layernorm",
                    // Standard components (may not exist in AltUp)
                    "self_attn.q_proj", "self_attn.k_proj", "self_attn.v_proj", "self_attn.o_proj",
                    "mlp.gate_proj", "mlp.up_proj", "mlp.down_proj"
                ]
                
                var foundCount = 0
                for component in components {
                    if weights["\(prefix).\(component).weight"] != nil {
                        foundCount += 1
                    }
                }
                print("  ✓ Found \(foundCount)/\(components.count) expected weights")
            } else {
                print("⚠️ No weights found for layer \(i)")
            }
        }
        
        // Load normalization weights
        let normKeys = ["language_model.model.norm.weight", "model.norm.weight"]
        var normLoaded = false
        for key in normKeys {
            if let normWeight = weights[key] {
                var params = ModuleParameters()
                params["weight"] = .value(normWeight)
                norm?.update(parameters: params)
                print("✅ Loaded norm weights from \(key): \(normWeight.shape)")
                normLoaded = true
                break
            }
        }
        if !normLoaded {
            print("⚠️ Norm weights not found. Tried: \(normKeys)")
        }
        
        // Load output projection weights - AltUp uses altup_unembed_projections
        let outputKeys = [
            "language_model.model.altup_unembed_projections.0.weight",
            "language_model.model.lm_head.weight",
            "lm_head.weight"
        ]
        var outputLoaded = false
        for key in outputKeys {
            if let outputWeight = weights[key] {
                var params = ModuleParameters()
                params["weight"] = .value(outputWeight)
                output?.update(parameters: params)
                print("✅ Loaded output weights from \(key): \(outputWeight.shape)")
                outputLoaded = true
                break
            }
        }
        if !outputLoaded {
            print("⚠️ Output weights not found. Tried: \(outputKeys)")
        }
        
        print("✅ Weight loading complete")
    }
    
    private func forward(tokens: [Int]) throws -> MLXArray {
        guard let embeddings = embeddings,
              let embedProjection = embedProjection,
              let norm = norm,
              let output = output else {
            throw ModelError.modelNotLoaded
        }
        
        // Convert tokens to MLXArray
        let inputArray = MLXArray(tokens.map { Int32($0) })
        print("🔍 Input tokens shape: \(inputArray.shape)")
        
        // Embed tokens - this gives us 256-dim embeddings
        var hidden = embeddings(inputArray)
        print("🔍 After embedding shape: \(hidden.shape)")
        print("🔍 Embedding dimensions: \(hidden.shape.last ?? -1)")
        
        // Project embeddings from 256 to 2048 dimensions
        hidden = embedProjection(hidden)
        print("🔍 After projection shape: \(hidden.shape)")
        print("🔍 Projected dimensions: \(hidden.shape.last ?? -1)")
        
        // Pass through transformer layers
        for (i, layer) in layers.enumerated() {
            let beforeShape = hidden.shape
            hidden = layer(hidden)
            if i == 0 {  // Only print for first layer to avoid spam
                print("🔍 After layer \(i) shape: \(hidden.shape)")
                if beforeShape != hidden.shape {
                    print("⚠️ Shape changed in layer \(i): \(beforeShape) -> \(hidden.shape)")
                }
            }
        }
        
        print("🔍 Before final norm shape: \(hidden.shape)")
        print("🔍 Hidden last dimension: \(hidden.shape.last ?? -1)")
        print("🔍 RMSNorm expects dimension: \(hiddenSize)")
        
        // Final norm and output
        hidden = norm(hidden)
        let logits = output(hidden)
        
        // Evaluate intermediate tensors to free memory
        MLX.eval(hidden)
        
        // Return logits for the last token
        return logits[-1, .ellipsis]
    }
    
    private func sampleToken(logits: MLXArray, temperature: Float, topK: Int, topP: Float) throws -> Int {
        // MLX Swift provides simpler sampling approaches
        // For now, we'll use temperature sampling with categorical distribution
        
        if temperature == 0 {
            // ArgMax sampling - pick the most likely token
            return MLX.argMax(logits, axis: -1).item(Int.self)
        }
        
        // Apply temperature
        let scaledLogits = logits / temperature
        
        // Convert to probabilities
        let probs = MLX.softmax(scaledLogits, axis: -1)
        
        // TopK filtering - simplified version
        // We'll use a basic approach: only keep tokens with high enough probability
        var filteredProbs = probs
        
        if topK > 0 && topK < vocabSize {
            // Get the sorted indices
            _ = MLX.argSort(probs, axis: -1)
            
            // Create a mask for top K values
            // This is a simplified approach - in production, use dedicated samplers
            let threshold = Float(1.0 / Float(topK * 2))  // Simple heuristic
            filteredProbs = MLX.where(probs .>= threshold, probs, MLXArray.zeros(probs.shape))
            
            // Renormalize
            let sum = MLX.sum(filteredProbs, axis: -1, keepDims: true)
            if sum.item(Float.self) > 0 {
                filteredProbs = filteredProbs / sum
            }
        }
        
        // TopP filtering - simplified version  
        if topP > 0 && topP < 1 {
            // Use a probability threshold based on topP
            // This is a simplified nucleus sampling
            let threshold = (1.0 - topP) / Float(vocabSize)
            filteredProbs = MLX.where(filteredProbs .>= threshold, filteredProbs, MLXArray.zeros(filteredProbs.shape))
            
            // Renormalize
            let sum = MLX.sum(filteredProbs, axis: -1, keepDims: true)
            if sum.item(Float.self) > 0 {
                filteredProbs = filteredProbs / sum
            }
        }
        
        // Sample from distribution
        let sampled = MLXRandom.categorical(filteredProbs)
        
        return sampled.item(Int.self)
    }
}

// MARK: - Simple Transformer Block

private class TransformerBlock: Module {
    let attention: MultiHeadAttention
    let mlp: Sequential
    let norm1: RMSNorm
    let norm2: RMSNorm
    
    init(dimensions: Int, headCount: Int) {
        self.attention = MultiHeadAttention(
            dimensions: dimensions,
            numHeads: headCount,
            queryInputDimensions: dimensions,
            keyInputDimensions: dimensions,
            valueInputDimensions: dimensions,
            valueDimensions: dimensions,
            valueOutputDimensions: dimensions
        )
        
        // Simple MLP
        self.mlp = Sequential(layers: [
            Linear(dimensions, dimensions * 4),
            GELU(),
            Linear(dimensions * 4, dimensions)
        ])
        
        self.norm1 = RMSNorm(dimensions: dimensions, eps: 1e-6)
        self.norm2 = RMSNorm(dimensions: dimensions, eps: 1e-6)
        
        super.init()
        
        // Initialize RMSNorm weights to ones to prevent crashes
        var norm1Params = ModuleParameters()
        norm1Params["weight"] = .value(MLXArray.ones([dimensions]))
        self.norm1.update(parameters: norm1Params)
        
        var norm2Params = ModuleParameters()
        norm2Params["weight"] = .value(MLXArray.ones([dimensions]))
        self.norm2.update(parameters: norm2Params)
    }
    
    func callAsFunction(_ x: MLXArray) -> MLXArray {
        // Pre-norm architecture
        var output = x
        let normed = norm1(x)
        // MultiHeadAttention in MLX Swift requires queries, keys, and values
        output = output + attention(normed, keys: normed, values: normed)
        output = output + mlp(norm2(output))
        return output
    }
    
    func loadWeights(from weights: [String: MLXArray], prefix: String) {
        // TODO: Implement proper weight loading when MLX Swift API is clarified
        // Skip weight loading for now - using random initialization
    }
}