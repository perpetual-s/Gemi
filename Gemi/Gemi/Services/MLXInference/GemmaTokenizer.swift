import Foundation

/// Tokenizer for Gemma models using SentencePiece vocabulary
@MainActor
class GemmaTokenizer {
    private var vocabulary: [String: Int] = [:]
    private var reverseVocabulary: [Int: String] = [:]
    private var merges: [(String, String)] = []
    
    // Special tokens
    private let padToken = "<pad>"
    private let eosToken = "<eos>"
    private let bosToken = "<bos>"
    private let unkToken = "<unk>"
    
    private var padTokenId: Int = 0
    private var eosTokenId: Int = 1
    private var bosTokenId: Int = 2
    private var unkTokenId: Int = 3
    
    struct TokenizerConfig: Codable {
        let model: TokenizerModel?
        let added_tokens: [AddedToken]?
        let normalizer: Normalizer?
        let pre_tokenizer: PreTokenizer?
        let post_processor: PostProcessor?
        let decoder: Decoder?
    }
    
    struct TokenizerModel: Codable {
        let type: String
        let vocab: [String: Int]?
        let merges: [String]?
    }
    
    struct AddedToken: Codable {
        let id: Int
        let content: String
        let single_word: Bool?
        let lstrip: Bool?
        let rstrip: Bool?
        let normalized: Bool?
        let special: Bool?
    }
    
    struct Normalizer: Codable {
        let type: String
    }
    
    struct PreTokenizer: Codable {
        let type: String
    }
    
    struct PostProcessor: Codable {
        let type: String
    }
    
    struct Decoder: Codable {
        let type: String
    }
    
    init(modelPath: URL) async throws {
        // Load tokenizer.json
        let tokenizerPath = modelPath.appendingPathComponent("tokenizer.json")
        
        // Check if tokenizer file exists
        guard FileManager.default.fileExists(atPath: tokenizerPath.path) else {
            throw ModelError.downloadFailed("tokenizer.json not found at \(tokenizerPath.path)")
        }
        
        let tokenizerData = try Data(contentsOf: tokenizerPath)
        
        // Try to decode with better error handling
        let config: TokenizerConfig
        do {
            config = try JSONDecoder().decode(TokenizerConfig.self, from: tokenizerData)
        } catch {
            // Print tokenizer data for debugging
            if let jsonString = String(data: tokenizerData, encoding: .utf8) {
                print("Failed to decode tokenizer.json. Content preview: \(String(jsonString.prefix(500)))")
            }
            print("Tokenizer decoding error: \(error)")
            throw ModelError.downloadFailed("Failed to decode tokenizer.json: \(error.localizedDescription)")
        }
        
        // Load vocabulary
        if let vocab = config.model?.vocab {
            self.vocabulary = vocab
            
            // Build reverse vocabulary
            for (token, id) in vocab {
                reverseVocabulary[id] = token
            }
            
            // Find special token IDs
            if let padId = vocab[padToken] { padTokenId = padId }
            if let eosId = vocab[eosToken] { eosTokenId = eosId }
            if let bosId = vocab[bosToken] { bosTokenId = bosId }
            if let unkId = vocab[unkToken] { unkTokenId = unkId }
        }
        
        // Load merges for BPE if available
        if let merges = config.model?.merges {
            self.merges = merges.compactMap { merge in
                let parts = merge.split(separator: " ")
                if parts.count == 2 {
                    return (String(parts[0]), String(parts[1]))
                }
                return nil
            }
        }
        
        // Add any additional special tokens
        if let addedTokens = config.added_tokens {
            for token in addedTokens {
                vocabulary[token.content] = token.id
                reverseVocabulary[token.id] = token.content
            }
        }
    }
    
    func encode(_ text: String) -> [Int] {
        // For Gemma, we typically use SentencePiece tokenization
        // This is a simplified version - in production, use proper SentencePiece
        
        var tokens: [Int] = []
        
        // Add BOS token
        tokens.append(bosTokenId)
        
        // Simple tokenization: split by spaces and punctuation
        let words = tokenizeText(text)
        
        for word in words {
            if let tokenId = vocabulary[word] {
                tokens.append(tokenId)
            } else {
                // Try to find subword tokens
                let subTokens = encodeSubword(word)
                tokens.append(contentsOf: subTokens)
            }
        }
        
        return tokens
    }
    
    func decode(_ tokens: [Int]) -> String {
        var text = ""
        
        for token in tokens {
            // Skip special tokens in decoding
            if token == padTokenId || token == bosTokenId {
                continue
            }
            
            if let str = reverseVocabulary[token] {
                // Handle SentencePiece's ▁ (underscore) for spaces
                let cleaned = str.replacingOccurrences(of: "▁", with: " ")
                text += cleaned
            }
        }
        
        // Clean up double spaces and trim
        text = text.replacingOccurrences(of: "  ", with: " ")
        return text.trimmingCharacters(in: .whitespaces)
    }
    
    func isEndToken(_ token: Int) -> Bool {
        return token == eosTokenId
    }
    
    // MARK: - Private Methods
    
    private func tokenizeText(_ text: String) -> [String] {
        // Simple tokenization by splitting on spaces and keeping punctuation
        var tokens: [String] = []
        var currentToken = ""
        
        for char in text {
            if char.isWhitespace {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                // Add space token with SentencePiece marker
                tokens.append("▁")
            } else if char.isPunctuation {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                tokens.append(String(char))
            } else {
                currentToken.append(char)
            }
        }
        
        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }
        
        return tokens
    }
    
    private func encodeSubword(_ word: String) -> [Int] {
        // Simple character-level fallback for unknown words
        var tokens: [Int] = []
        
        // Try to match prefixes in vocabulary
        var remaining = word
        while !remaining.isEmpty {
            var found = false
            
            // Try longest prefix first
            for length in stride(from: remaining.count, to: 0, by: -1) {
                let prefix = String(remaining.prefix(length))
                if let tokenId = vocabulary[prefix] {
                    tokens.append(tokenId)
                    remaining = String(remaining.dropFirst(length))
                    found = true
                    break
                }
            }
            
            if !found {
                // If no prefix found, use unknown token and move to next character
                tokens.append(unkTokenId)
                remaining = String(remaining.dropFirst())
            }
        }
        
        return tokens
    }
}

// MARK: - Extensions for Gemma-specific tokenization

extension GemmaTokenizer {
    /// Load tokenizer config for Gemma models
    func loadGemmaConfig(from path: URL) throws {
        // Load tokenizer_config.json if available
        let configPath = path.appendingPathComponent("tokenizer_config.json")
        if FileManager.default.fileExists(atPath: configPath.path) {
            let configData = try Data(contentsOf: configPath)
            if let config = try JSONSerialization.jsonObject(with: configData) as? [String: Any] {
                // Extract any Gemma-specific settings
                if let eosToken = config["eos_token"] as? String,
                   let eosId = vocabulary[eosToken] {
                    self.eosTokenId = eosId
                }
                
                if let bosToken = config["bos_token"] as? String,
                   let bosId = vocabulary[bosToken] {
                    self.bosTokenId = bosId
                }
            }
        }
    }
    
    /// Get vocabulary size
    var vocabularySize: Int {
        return vocabulary.count
    }
}