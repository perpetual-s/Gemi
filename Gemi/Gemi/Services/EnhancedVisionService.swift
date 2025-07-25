import Foundation
import Vision
import AppKit
import os.log

/// Enhanced vision service with real-time feedback and better performance
@MainActor
final class EnhancedVisionService: ObservableObject {
    static let shared = EnhancedVisionService()
    
    // MARK: - Published Properties
    
    @Published var isProcessing = false
    @Published var currentInsights: [VisionInsight] = []
    @Published var lastError: Error?
    
    // MARK: - Types
    
    struct VisionInsight: Identifiable {
        let id = UUID()
        let type: InsightType
        let description: String
        let confidence: Float
        let timestamp = Date()
        
        enum InsightType {
            case text, object, face, scene, emotion, document
            
            var priority: Int {
                switch self {
                case .text: return 1
                case .document: return 2
                case .face: return 3
                case .object: return 4
                case .scene: return 5
                case .emotion: return 6
                }
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.gemi", category: "EnhancedVision")
    private let processingQueue = DispatchQueue(label: "com.gemi.enhancedvision", qos: .userInitiated)
    
    // Smart caching
    private var insightCache = NSCache<NSString, NSArray>()
    
    // MARK: - Initialization
    
    private init() {
        insightCache.countLimit = 20
        insightCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
    
    // MARK: - Public Methods
    
    /// Perform intelligent image analysis with real-time feedback
    func analyzeWithInsights(_ image: NSImage) async throws -> String {
        logger.info("Starting enhanced image analysis")
        
        isProcessing = true
        currentInsights = []
        defer { isProcessing = false }
        
        // Check cache
        let cacheKey = imageCacheKey(image)
        if let cachedInsights = insightCache.object(forKey: cacheKey as NSString) as? [VisionInsight] {
            currentInsights = cachedInsights
            return buildDescription(from: cachedInsights)
        }
        
        // Convert to CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.invalidImage
        }
        
        // Perform parallel analysis
        async let textInsights = extractTextInsights(from: cgImage)
        async let objectInsights = detectObjectInsights(from: cgImage)
        async let sceneInsights = classifySceneInsights(from: cgImage)
        
        // Combine results
        let allInsights = try await [textInsights, objectInsights, sceneInsights].flatMap { $0 }
            .sorted { $0.type.priority < $1.type.priority }
        
        // Update UI progressively
        for insight in allInsights {
            currentInsights.append(insight)
            postInsightUpdate(insight)
            
            // Small delay for visual feedback
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Cache results
        insightCache.setObject(allInsights as NSArray, forKey: cacheKey as NSString)
        
        return buildDescription(from: allInsights)
    }
    
    // MARK: - Text Analysis
    
    private func extractTextInsights(from cgImage: CGImage) async throws -> [VisionInsight] {
        postAnalysisUpdate("Looking for text...")
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    var insights: [VisionInsight] = []
                    
                    // Group text by regions
                    let significantText = observations
                        .compactMap { $0.topCandidates(1).first }
                        .filter { $0.confidence > 0.5 }
                    
                    if !significantText.isEmpty {
                        // Detect document type
                        let allText = significantText.map { $0.string }.joined(separator: " ")
                        
                        if allText.count > 100 {
                            insights.append(VisionInsight(
                                type: .document,
                                description: "Document with \(significantText.count) text regions",
                                confidence: 0.9
                            ))
                        }
                        
                        // Extract key phrases
                        let keyPhrases = self.extractKeyPhrases(from: allText)
                        for phrase in keyPhrases.prefix(3) {
                            insights.append(VisionInsight(
                                type: .text,
                                description: "Text: \"\(phrase)\"",
                                confidence: 0.8
                            ))
                        }
                    }
                    
                    continuation.resume(returning: insights)
                }
                
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
            }
        }
    }
    
    // MARK: - Object Detection
    
    private func detectObjectInsights(from cgImage: CGImage) async throws -> [VisionInsight] {
        postAnalysisUpdate("Identifying objects...")
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                var insights: [VisionInsight] = []
                
                // Face detection
                let faceRequest = VNDetectFaceRectanglesRequest { request, error in
                    if let observations = request.results as? [VNFaceObservation], !observations.isEmpty {
                        let faceCount = observations.count
                        insights.append(VisionInsight(
                            type: .face,
                            description: "\(faceCount) \(faceCount == 1 ? "person" : "people")",
                            confidence: observations[0].confidence
                        ))
                        
                        // Analyze expressions if available
                        if let firstFace = observations.first,
                           let _ = firstFace.landmarks {
                            insights.append(VisionInsight(
                                type: .emotion,
                                description: "Facial expression detected",
                                confidence: 0.7
                            ))
                        }
                    }
                }
                
                // Object detection
                let objectRequest = VNRecognizeAnimalsRequest { request, error in
                    if let observations = request.results as? [VNRecognizedObjectObservation] {
                        for observation in observations.prefix(3) {
                            if let label = observation.labels.first {
                                insights.append(VisionInsight(
                                    type: .object,
                                    description: label.identifier.replacingOccurrences(of: "_", with: " "),
                                    confidence: label.confidence
                                ))
                            }
                        }
                    }
                }
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([faceRequest, objectRequest])
                
                continuation.resume(returning: insights)
            }
        }
    }
    
    // MARK: - Scene Classification
    
    private func classifySceneInsights(from cgImage: CGImage) async throws -> [VisionInsight] {
        postAnalysisUpdate("Understanding the scene...")
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                var insights: [VisionInsight] = []
                
                let request = VNClassifyImageRequest { request, error in
                    guard let observations = request.results as? [VNClassificationObservation] else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                // Get top classifications
                    let topClassifications = observations
                        .filter { $0.confidence > 0.3 }
                        .prefix(3)
                    
                    for classification in topClassifications {
                        let cleanLabel = classification.identifier
                            .replacingOccurrences(of: "_", with: " ")
                            .replacingOccurrences(of: ",", with: "")
                        
                        insights.append(VisionInsight(
                            type: .scene,
                            description: cleanLabel,
                            confidence: classification.confidence
                        ))
                    }
                    
                    continuation.resume(returning: insights)
                }
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func buildDescription(from insights: [VisionInsight]) -> String {
        if insights.isEmpty {
            return "an image"
        }
        
        var description = ""
        
        // Start with document or scene
        if let docInsight = insights.first(where: { $0.type == .document }) {
            description = docInsight.description
        } else if let sceneInsight = insights.first(where: { $0.type == .scene }) {
            description = "a photo showing \(sceneInsight.description)"
        }
        
        // Add people if present
        if let faceInsight = insights.first(where: { $0.type == .face }) {
            description += description.isEmpty ? "A photo with " : " with "
            description += faceInsight.description
        }
        
        // Add key text if found
        let textInsights = insights.filter { $0.type == .text }.prefix(2)
        if !textInsights.isEmpty {
            let textParts = textInsights.map { $0.description }
            description += ". " + textParts.joined(separator: " and ")
        }
        
        return description
    }
    
    nonisolated private func extractKeyPhrases(from text: String) -> [String] {
        // Simple key phrase extraction
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        var phrases: [String] = []
        
        // Add first sentence if short enough
        if let firstSentence = sentences.first?.trimmingCharacters(in: .whitespaces),
           firstSentence.count < 50 {
            phrases.append(firstSentence)
        }
        
        // Add prominent words
        let importantWords = words.filter { $0.count > 5 && $0.first?.isUppercase == true }
        phrases.append(contentsOf: importantWords.prefix(3))
        
        return phrases
    }
    
    private func imageCacheKey(_ image: NSImage) -> String {
        guard let tiffData = image.tiffRepresentation else { return "" }
        return "\(tiffData.hashValue)"
    }
    
    private func postAnalysisUpdate(_ message: String) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: NSNotification.Name("MultimodalAnalysisUpdate"),
                object: message
            )
        }
    }
    
    private func postInsightUpdate(_ insight: VisionInsight) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: NSNotification.Name("VisionInsightDiscovered"),
                object: insight
            )
        }
    }
    
    // MARK: - Error Types
    
    enum VisionError: LocalizedError {
        case invalidImage
        case analysisTimeout
        
        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Could not process this image"
            case .analysisTimeout:
                return "Image analysis took too long"
            }
        }
    }
}