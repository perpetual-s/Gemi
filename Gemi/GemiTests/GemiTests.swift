//
//  GemiTests.swift
//  GemiTests
//
//  Created by Chaeho Shin on 7/5/25.
//

import Testing
@testable import Gemi
import Foundation

struct GemiTests {
    
    // MARK: - MLX Inference Tests
    
    @Test func testModelCacheInitialization() async throws {
        let cache = await ModelCache.shared
        // Just test that it initializes without error
        #expect(cache != nil)
    }
    
    @Test @MainActor func testGemmaMLXModelInitialization() async throws {
        let model = GemmaMLXModel()
        #expect(!model.isLoaded)
        #expect(model.loadProgress == 0.0)
    }
    
    @Test func testNativeChatServiceHealthCheck() async throws {
        let service = await NativeChatService.shared
        let health = await service.health()
        
        // Health returns a simple structure
        #expect(health != nil)
    }
    
    @Test func testSafetensorsHeader() async throws {
        // Test safetensors header parsing
        let testHeader = """
        {"test_tensor": {"dtype": "F32", "shape": [2, 3], "data_offsets": [0, 24]}}
        """
        let headerData = testHeader.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(
            [String: SafetensorsLoader.TensorInfo].self,
            from: headerData
        )
        
        #expect(decoded["test_tensor"] != nil)
        #expect(decoded["test_tensor"]?.dtype == "F32")
        #expect(decoded["test_tensor"]?.shape == [2, 3])
    }
    
    // MARK: - Model Config Tests
    
    @Test func testModelConfigDecoding() async throws {
        let configJSON = """
        {
            "model_type": "gemma",
            "num_hidden_layers": 12,
            "hidden_size": 768,
            "num_attention_heads": 12,
            "vocab_size": 32000,
            "intermediate_size": 3072,
            "num_key_value_heads": 12,
            "head_dim": 64,
            "max_position_embeddings": 2048,
            "rms_norm_eps": 1e-06,
            "rope_theta": 10000.0,
            "attention_bias": false,
            "attention_dropout": 0.0,
            "mlp_bias": false
        }
        """
        
        let data = configJSON.data(using: .utf8)!
        let config = try JSONDecoder().decode(ModelConfig.self, from: data)
        
        #expect(config.modelType == "gemma")
        #expect(config.numLayers == 12)
        #expect(config.hiddenSize == 768)
        #expect(config.numHeads == 12)
        #expect(config.vocabSize == 32000)
        #expect(config.intermediateSize == 3072)
        #expect(config.numKeyValueHeads == 12)
    }
}
