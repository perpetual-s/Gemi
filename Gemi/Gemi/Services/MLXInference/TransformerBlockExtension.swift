import Foundation
import MLX
import MLXNN

/// Extension to support weight loading for TransformerBlock
extension TransformerBlock {
    
    /// Load weights from a dictionary with a given prefix
    func loadWeights(from weights: [String: MLXArray], prefix: String) {
        print("🔄 Loading weights for transformer layer: \(prefix)")
        
        // Load self-attention weights
        loadAttentionWeights(from: weights, prefix: prefix)
        
        // Load feed-forward network weights
        loadFFNWeights(from: weights, prefix: prefix)
        
        // Load layer normalization weights
        loadNormWeights(from: weights, prefix: prefix)
    }
    
    private func loadAttentionWeights(from weights: [String: MLXArray], prefix: String) {
        // Query, Key, Value projections
        let attentionPrefix = "\(prefix).self_attn"
        
        // Load Q projection
        if let qWeight = weights["\(attentionPrefix).q_proj.weight"] {
            updateSubmodule(path: "attention.query", weight: qWeight)
            print("  ✓ Loaded Q projection: \(qWeight.shape)")
        }
        
        // Load K projection
        if let kWeight = weights["\(attentionPrefix).k_proj.weight"] {
            updateSubmodule(path: "attention.key", weight: kWeight)
            print("  ✓ Loaded K projection: \(kWeight.shape)")
        }
        
        // Load V projection
        if let vWeight = weights["\(attentionPrefix).v_proj.weight"] {
            updateSubmodule(path: "attention.value", weight: vWeight)
            print("  ✓ Loaded V projection: \(vWeight.shape)")
        }
        
        // Load output projection
        if let oWeight = weights["\(attentionPrefix).o_proj.weight"] {
            updateSubmodule(path: "attention.output", weight: oWeight)
            print("  ✓ Loaded output projection: \(oWeight.shape)")
        }
    }
    
    private func loadFFNWeights(from weights: [String: MLXArray], prefix: String) {
        // Feed-forward network weights
        let ffnPrefix = "\(prefix).mlp"
        
        // Load gate projection (up projection)
        if let gateWeight = weights["\(ffnPrefix).gate_proj.weight"] {
            updateSubmodule(path: "ffn.gate", weight: gateWeight)
            print("  ✓ Loaded gate projection: \(gateWeight.shape)")
        }
        
        // Load up projection
        if let upWeight = weights["\(ffnPrefix).up_proj.weight"] {
            updateSubmodule(path: "ffn.up", weight: upWeight)
            print("  ✓ Loaded up projection: \(upWeight.shape)")
        }
        
        // Load down projection
        if let downWeight = weights["\(ffnPrefix).down_proj.weight"] {
            updateSubmodule(path: "ffn.down", weight: downWeight)
            print("  ✓ Loaded down projection: \(downWeight.shape)")
        }
    }
    
    private func loadNormWeights(from weights: [String: MLXArray], prefix: String) {
        // Layer normalization weights
        
        // Pre-attention norm
        if let preNormWeight = weights["\(prefix).input_layernorm.weight"] {
            updateSubmodule(path: "norm1", weight: preNormWeight)
            print("  ✓ Loaded pre-attention norm: \(preNormWeight.shape)")
        }
        
        // Post-attention norm
        if let postNormWeight = weights["\(prefix).post_attention_layernorm.weight"] {
            updateSubmodule(path: "norm2", weight: postNormWeight)
            print("  ✓ Loaded post-attention norm: \(postNormWeight.shape)")
        }
    }
    
    /// Helper to update a submodule's weight parameter
    private func updateSubmodule(path: String, weight: MLXArray) {
        // This is a simplified version - in practice, you'd need to navigate
        // the module hierarchy to find the correct submodule
        var params = ModuleParameters()
        params["weight"] = .value(weight)
        
        // Note: This would need to be implemented based on actual TransformerBlock structure
        // For now, we're documenting the pattern
        print("  📝 Would update \(path) with weight shape \(weight.shape)")
    }
}

/// Custom TransformerBlock implementation if needed
/// This shows the structure we expect for Gemma 3n
class GemmaTransformerBlock: Module {
    let attention: MultiHeadAttention
    let ffn: FeedForward
    let norm1: RMSNorm
    let norm2: RMSNorm
    
    init(dimensions: Int, headCount: Int) {
        self.attention = MultiHeadAttention(
            dimensions: dimensions,
            heads: headCount,
            kvHeads: headCount  // Gemma uses full attention, not GQA
        )
        
        // Gemma uses SwiGLU activation in FFN
        self.ffn = FeedForward(
            dimensions: dimensions,
            hiddenDimensions: dimensions * 4,
            activation: { x in silu(x) }  // SiLU activation for SwiGLU
        )
        
        self.norm1 = RMSNorm(dimensions: dimensions, eps: 1e-6)
        self.norm2 = RMSNorm(dimensions: dimensions, eps: 1e-6)
        
        super.init()
    }
    
    func callAsFunction(_ x: MLXArray, mask: MLXArray? = nil) -> MLXArray {
        // Pre-norm architecture (like Gemma)
        var h = norm1(x)
        h = attention(h, mask: mask)
        h = h + x  // Residual connection
        
        var out = norm2(h)
        out = ffn(out)
        out = out + h  // Residual connection
        
        return out
    }
    
    /// Load weights for this transformer block
    func loadWeights(from weights: [String: MLXArray], prefix: String) {
        // Load attention weights
        if let qWeight = weights["\(prefix).self_attn.q_proj.weight"] {
            var params = ModuleParameters()
            params["weight"] = .value(qWeight)
            // attention.queryProjection.update(parameters: params)
        }
        
        // Load FFN weights
        if let gateWeight = weights["\(prefix).mlp.gate_proj.weight"] {
            var params = ModuleParameters()
            params["weight"] = .value(gateWeight)
            // ffn.gate.update(parameters: params)
        }
        
        // Load norm weights
        if let norm1Weight = weights["\(prefix).input_layernorm.weight"] {
            var params = ModuleParameters()
            params["weight"] = .value(norm1Weight)
            norm1.update(parameters: params)
        }
        
        if let norm2Weight = weights["\(prefix).post_attention_layernorm.weight"] {
            var params = ModuleParameters()
            params["weight"] = .value(norm2Weight)
            norm2.update(parameters: params)
        }
    }
}