import Foundation

/// HuggingFace Configuration
/// 
/// SETUP INSTRUCTIONS:
/// 1. Copy this file to HuggingFaceConfig.swift (remove .example)
/// 2. Replace YOUR_TOKEN_HERE with your actual HuggingFace token
/// 3. CRITICAL: Token MUST have WRITE permissions (not just read)
/// 4. Get your token from: https://huggingface.co/settings/tokens
/// 5. Accept the model license at: https://huggingface.co/google/gemma-3n-E4B-it
/// 
/// This file is gitignored to protect your token
struct HuggingFaceConfig {
    static let token = "YOUR_TOKEN_HERE"
    
    // Verify token is set
    static var isConfigured: Bool {
        token != "YOUR_TOKEN_HERE" && !token.isEmpty
    }
}