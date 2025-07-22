import Foundation
import Vision
import AppKit
import CoreImage

/// Service for analyzing images using Apple's Vision framework
/// Provides text extraction, image classification, object detection, and scene analysis
@MainActor
final class VisionAnalysisService: ObservableObject {
    static let shared = VisionAnalysisService()
    
    // MARK: - Types
    
    struct AnalysisResult {
        let text: String?
        let classifications: [Classification]
        let objects: [DetectedObject]
        let scenes: [String]
        let fullDescription: String
        let processingTime: TimeInterval
    }
    
    struct Classification {
        let identifier: String
        let confidence: Float
        
        var formattedConfidence: String {
            String(format: "%.1f%%", confidence * 100)
        }
    }
    
    struct DetectedObject {
        let label: String
        let confidence: Float
        let boundingBox: CGRect
    }
    
    enum AnalysisError: LocalizedError {
        case imageLoadFailed
        case noResultsFound
        case processingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .imageLoadFailed:
                return "Failed to load or process the image"
            case .noResultsFound:
                return "No analysis results were found"
            case .processingFailed(let reason):
                return "Analysis failed: \(reason)"
            }
        }
    }
    
    // MARK: - Properties
    
    @Published var isAnalyzing = false
    @Published var progress: Double = 0
    @Published var currentOperation = ""
    
    // Request configuration
    private let textRecognitionLanguages = ["en-US", "es-ES", "fr-FR", "de-DE", "it-IT", "pt-BR", "zh-Hans", "ja-JP", "ko-KR"]
    private let classificationConfidenceThreshold: Float = 0.1
    private let objectDetectionConfidenceThreshold: Float = 0.3
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Analyze an image and extract all available information
    func analyzeImage(_ image: NSImage) async throws -> AnalysisResult {
        isAnalyzing = true
        progress = 0
        defer { 
            isAnalyzing = false
            currentOperation = ""
        }
        
        let startTime = Date()
        
        // Convert NSImage to CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AnalysisError.imageLoadFailed
        }
        
        // Create handler
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Perform all analyses in parallel
        async let textResult = extractText(from: handler)
        async let classificationResult = classifyImage(with: handler)
        async let objectResult = detectObjects(in: handler)
        async let sceneResult = analyzeScenes(in: handler)
        
        // Wait for all results
        let (text, classifications, objects, scenes) = try await (textResult, classificationResult, objectResult, sceneResult)
        
        // Generate comprehensive description
        let fullDescription = generateDescription(
            text: text,
            classifications: classifications,
            objects: objects,
            scenes: scenes
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return AnalysisResult(
            text: text,
            classifications: classifications,
            objects: objects,
            scenes: scenes,
            fullDescription: fullDescription,
            processingTime: processingTime
        )
    }
    
    /// Extract text from an image using OCR
    func extractText(from image: NSImage) async throws -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AnalysisError.imageLoadFailed
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        return try await extractText(from: handler)
    }
    
    /// Classify an image and return top categories
    func classifyImage(_ image: NSImage) async throws -> [Classification] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AnalysisError.imageLoadFailed
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        return try await classifyImage(with: handler)
    }
    
    // MARK: - Private Analysis Methods
    
    private func extractText(from handler: VNImageRequestHandler) async throws -> String? {
        currentOperation = "Extracting text..."
        progress = 0.1
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Extract all recognized text
                let recognizedText = observations
                    .compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    .joined(separator: "\n")
                
                continuation.resume(returning: recognizedText.isEmpty ? nil : recognizedText)
            }
            
            // Configure request
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = textRecognitionLanguages
            
            // Perform request
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
            }
        }
    }
    
    private func classifyImage(with handler: VNImageRequestHandler) async throws -> [Classification] {
        currentOperation = "Classifying image..."
        progress = 0.3
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Filter and map classifications
                let classifications = observations
                    .filter { $0.confidence >= self.classificationConfidenceThreshold }
                    .prefix(10) // Top 10 classifications
                    .map { Classification(identifier: $0.identifier, confidence: $0.confidence) }
                
                continuation.resume(returning: Array(classifications))
            }
            
            // Perform request
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
            }
        }
    }
    
    private func detectObjects(in handler: VNImageRequestHandler) async throws -> [DetectedObject] {
        currentOperation = "Detecting objects..."
        progress = 0.5
        
        return try await withCheckedThrowingContinuation { continuation in
            // Use saliency detection for object identification
            let request = VNGenerateObjectnessBasedSaliencyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
                    return
                }
                
                guard let observation = request.results?.first as? VNSaliencyImageObservation else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Get salient objects
                let salientObjects = observation.salientObjects ?? []
                
                let objects = salientObjects
                    .filter { $0.confidence >= self.objectDetectionConfidenceThreshold }
                    .prefix(5) // Top 5 objects
                    .enumerated()
                    .map { index, object in
                        DetectedObject(
                            label: "Object \(index + 1)",
                            confidence: object.confidence,
                            boundingBox: object.boundingBox
                        )
                    }
                
                continuation.resume(returning: Array(objects))
            }
            
            // Perform request
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
            }
        }
    }
    
    private func analyzeScenes(in handler: VNImageRequestHandler) async throws -> [String] {
        currentOperation = "Analyzing scenes..."
        progress = 0.7
        
        // For scene analysis, we'll use image classification results
        // and extract scene-related classifications
        let classifications = try await classifyImage(with: handler)
        
        // Filter for scene-related classifications
        let sceneKeywords = ["outdoor", "indoor", "nature", "urban", "landscape", "room", "building", "street", "forest", "beach", "mountain", "sky", "water"]
        
        let scenes = classifications
            .filter { classification in
                sceneKeywords.contains { keyword in
                    classification.identifier.lowercased().contains(keyword)
                }
            }
            .map { $0.identifier }
        
        return Array(scenes.prefix(5))
    }
    
    // MARK: - Description Generation
    
    private func generateDescription(text: String?, classifications: [Classification], objects: [DetectedObject], scenes: [String]) -> String {
        currentOperation = "Generating description..."
        progress = 0.9
        
        var description = "Image Analysis Results:\n\n"
        
        // Add scene information
        if !scenes.isEmpty {
            description += "Scene: This appears to be \(scenes.joined(separator: ", ")).\n\n"
        }
        
        // Add main classifications
        if !classifications.isEmpty {
            let topClassifications = classifications.prefix(3)
            description += "Main Content: The image contains "
            description += topClassifications.map { "\($0.identifier) (\($0.formattedConfidence))" }.joined(separator: ", ")
            description += ".\n\n"
        }
        
        // Add object detection results
        if !objects.isEmpty {
            description += "Detected Objects: Found \(objects.count) distinct object(s) in the image"
            if let mostConfident = objects.max(by: { $0.confidence < $1.confidence }) {
                description += ", with the most prominent at \(String(format: "%.1f%%", mostConfident.confidence * 100)) confidence"
            }
            description += ".\n\n"
        }
        
        // Add extracted text
        if let text = text, !text.isEmpty {
            description += "Text Content:\n\(text)\n\n"
        }
        
        // Add additional context based on classifications
        let contextualInfo = generateContextualInfo(from: classifications)
        if !contextualInfo.isEmpty {
            description += "Additional Context: \(contextualInfo)\n"
        }
        
        progress = 1.0
        return description
    }
    
    private func generateContextualInfo(from classifications: [Classification]) -> String {
        var contexts: [String] = []
        
        // Check for specific types of content
        let classificationIdentifiers = classifications.map { $0.identifier.lowercased() }
        
        if classificationIdentifiers.contains(where: { $0.contains("document") || $0.contains("text") || $0.contains("paper") }) {
            contexts.append("This appears to be a document or text-based content")
        }
        
        if classificationIdentifiers.contains(where: { $0.contains("screenshot") || $0.contains("screen") || $0.contains("display") }) {
            contexts.append("This looks like a screenshot or digital display")
        }
        
        if classificationIdentifiers.contains(where: { $0.contains("chart") || $0.contains("graph") || $0.contains("diagram") }) {
            contexts.append("Contains data visualization elements")
        }
        
        if classificationIdentifiers.contains(where: { $0.contains("person") || $0.contains("people") || $0.contains("face") }) {
            contexts.append("Contains human subjects")
        }
        
        return contexts.joined(separator: ". ")
    }
    
    // MARK: - Utility Methods
    
    /// Convert analysis result to text suitable for LLM input
    func convertToLLMInput(_ result: AnalysisResult) -> String {
        var input = "Image Description for AI Assistant:\n\n"
        
        input += result.fullDescription
        
        // Add metadata
        input += "\n---\n"
        input += "Analysis completed in \(String(format: "%.2f", result.processingTime)) seconds.\n"
        
        if !result.classifications.isEmpty {
            input += "Top classifications: \(result.classifications.prefix(5).map { $0.identifier }.joined(separator: ", "))\n"
        }
        
        if let text = result.text {
            let wordCount = text.split(separator: " ").count
            input += "Extracted \(wordCount) words of text.\n"
        }
        
        return input
    }
    
    /// Create a thumbnail preview of the analyzed image with overlays
    func createAnalysisPreview(for image: NSImage, with result: AnalysisResult) -> NSImage? {
        let imageSize = image.size
        let preview = NSImage(size: imageSize)
        
        preview.lockFocus()
        
        // Draw original image
        image.draw(in: NSRect(origin: .zero, size: imageSize))
        
        // Draw object bounding boxes if available
        NSColor.systemGreen.withAlphaComponent(0.3).setFill()
        NSColor.systemGreen.setStroke()
        
        for object in result.objects {
            // Convert normalized coordinates to image coordinates
            let rect = NSRect(
                x: object.boundingBox.origin.x * imageSize.width,
                y: (1 - object.boundingBox.origin.y - object.boundingBox.height) * imageSize.height,
                width: object.boundingBox.width * imageSize.width,
                height: object.boundingBox.height * imageSize.height
            )
            
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 2
            path.fill()
            path.stroke()
        }
        
        preview.unlockFocus()
        
        return preview
    }
}

// MARK: - Vision Framework Extensions

extension VisionAnalysisService {
    /// Additional specialized analysis methods
    
    /// Detect faces in an image
    func detectFaces(in image: NSImage) async throws -> [VNFaceObservation] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AnalysisError.imageLoadFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
                    return
                }
                
                let observations = request.results as? [VNFaceObservation] ?? []
                continuation.resume(returning: observations)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
            }
        }
    }
    
    /// Detect barcodes and QR codes
    func detectBarcodes(in image: NSImage) async throws -> [VNBarcodeObservation] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AnalysisError.imageLoadFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
                    return
                }
                
                let observations = request.results as? [VNBarcodeObservation] ?? []
                continuation.resume(returning: observations)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
            }
        }
    }
    
    /// Analyze image aesthetics and composition
    func analyzeComposition(of image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AnalysisError.imageLoadFailed
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Use attention-based saliency to understand composition
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateAttentionBasedSaliencyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
                    return
                }
                
                guard let observation = request.results?.first as? VNSaliencyImageObservation else {
                    continuation.resume(returning: "Unable to analyze image composition")
                    return
                }
                
                // Analyze the heat map to understand composition
                let salientObjects = observation.salientObjects ?? []
                
                var composition = "Image Composition Analysis:\n"
                
                if salientObjects.isEmpty {
                    composition += "The image has a uniform composition without distinct focal points."
                } else if salientObjects.count == 1 {
                    composition += "The image has a single clear focal point"
                    if let object = salientObjects.first {
                        let position = self.describePosition(of: object.boundingBox)
                        composition += " located \(position)."
                    }
                } else {
                    composition += "The image has \(salientObjects.count) distinct areas of interest"
                    let positions = salientObjects.prefix(3).map { self.describePosition(of: $0.boundingBox) }
                    composition += " located at: \(positions.joined(separator: ", "))."
                }
                
                continuation.resume(returning: composition)
            }
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
            }
        }
    }
    
    private func describePosition(of boundingBox: CGRect) -> String {
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY
        
        var position = ""
        
        // Vertical position
        if centerY < 0.33 {
            position += "bottom"
        } else if centerY > 0.66 {
            position += "top"
        } else {
            position += "center"
        }
        
        // Horizontal position
        if centerX < 0.33 {
            position += " left"
        } else if centerX > 0.66 {
            position += " right"
        } else if position == "center" {
            position = "center"
        }
        
        return position
    }
}