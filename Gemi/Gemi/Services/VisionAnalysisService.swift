import Foundation
@preconcurrency import Vision
import AppKit
import CoreImage
import os.log

/// Comprehensive Vision framework service for analyzing images locally
@MainActor
final class VisionAnalysisService: ObservableObject {
    static let shared = VisionAnalysisService()
    
    
    // MARK: - Published Properties
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    @Published var lastError: Error?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.gemi", category: "VisionAnalysis")
    private let processingQueue = DispatchQueue(label: "com.gemi.vision", qos: .userInitiated)
    
    // Cache for recent analyses
    private var analysisCache = NSCache<NSString, CachedAnalysis>()
    
    // MARK: - Types
    
    struct AnalysisOptions {
        var extractText = true
        var classifyImage = true
        var detectObjects = true
        var detectFaces = false
        var detectBarcodes = false
        var analyzeComposition = true
        var generateCaption = true
        var detectHorizon = false
        var recognizeAnimals = true
        var detectTextRectangles = true
    }
    
    struct AnalysisResult {
        let extractedText: String
        let classifications: [VNClassificationObservation]
        let detectedObjects: [VNRecognizedObjectObservation]
        let faceCount: Int
        let faceDetails: [FaceDetail]
        let barcodes: [BarcodeInfo]
        let textRectangles: [CGRect]
        let dominantColors: [NSColor]
        let imageProperties: ImageProperties
        let salientRegions: [CGRect]
        let horizon: HorizonInfo?
        let additionalInfo: [String: Any]
        let processingTime: TimeInterval
    }
    
    struct FaceDetail {
        let boundingBox: CGRect
        let landmarks: VNFaceLandmarks2D?
        let confidence: Float
        let attributes: [String: Any]
    }
    
    struct BarcodeInfo {
        let symbology: VNBarcodeSymbology
        let payloadString: String?
        let boundingBox: CGRect
    }
    
    struct ImageProperties {
        let width: Int
        let height: Int
        let orientation: CGImagePropertyOrientation
        let hasAlpha: Bool
        let colorSpace: String
        let fileSize: Int64?
    }
    
    struct HorizonInfo {
        let angle: Double
        let confidence: Float
    }
    
    private class CachedAnalysis {
        let result: AnalysisResult
        let timestamp: Date
        
        init(result: AnalysisResult) {
            self.result = result
            self.timestamp = Date()
        }
    }
    
    enum AnalysisError: LocalizedError {
        case invalidImage
        case processingFailed(String)
        case noResultsFound
        
        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "The provided image is invalid or corrupted"
            case .processingFailed(let reason):
                return "Image analysis failed: \(reason)"
            case .noResultsFound:
                return "No meaningful results found in the image"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        analysisCache.countLimit = 10
        analysisCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    // MARK: - Public Methods
    
    /// Analyze an image with specified options
    func analyzeImage(_ image: NSImage, options: AnalysisOptions = AnalysisOptions()) async throws -> AnalysisResult {
        logger.info("Starting image analysis with options")
        
        let startTime = Date()
        isProcessing = true
        processingProgress = 0
        defer { 
            isProcessing = false
            processingProgress = 0
        }
        
        // Check cache first
        let cacheKey = imageCacheKey(image)
        if let cached = analysisCache.object(forKey: cacheKey as NSString) {
            logger.debug("Returning cached analysis result")
            return cached.result
        }
        
        // Convert NSImage to CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AnalysisError.invalidImage
        }
        
        // Prepare image properties
        let properties = extractImageProperties(from: image)
        
        // Create Vision requests based on options
        var requests: [VNRequest] = []
        var requestCount = 0
        
        if options.extractText {
            requests.append(createTextRecognitionRequest())
            requestCount += 1
        }
        
        if options.classifyImage {
            requests.append(createClassificationRequest())
            requestCount += 1
        }
        
        if options.detectObjects {
            requests.append(createObjectDetectionRequest())
            requestCount += 1
        }
        
        if options.detectFaces {
            requests.append(createFaceDetectionRequest())
            requestCount += 1
        }
        
        if options.detectBarcodes {
            requests.append(createBarcodeDetectionRequest())
            requestCount += 1
        }
        
        if options.detectTextRectangles {
            requests.append(createTextRectangleRequest())
            requestCount += 1
        }
        
        if options.analyzeComposition {
            requests.append(createSaliencyRequest())
            requestCount += 1
        }
        
        if options.detectHorizon {
            requests.append(createHorizonRequest())
            requestCount += 1
        }
        
        // Process requests
        let results = try await processRequests(requests, on: cgImage, totalCount: requestCount)
        
        // Extract colors
        let dominantColors = options.analyzeComposition ? extractDominantColors(from: cgImage) : []
        
        // Build final result
        let result = AnalysisResult(
            extractedText: results.extractedText,
            classifications: results.classifications,
            detectedObjects: results.detectedObjects,
            faceCount: results.faces.count,
            faceDetails: results.faces,
            barcodes: results.barcodes,
            textRectangles: results.textRectangles,
            dominantColors: dominantColors,
            imageProperties: properties,
            salientRegions: results.salientRegions,
            horizon: results.horizon,
            additionalInfo: buildAdditionalInfo(from: results, options: options),
            processingTime: Date().timeIntervalSince(startTime)
        )
        
        // Cache the result
        let cached = CachedAnalysis(result: result)
        analysisCache.setObject(cached, forKey: cacheKey as NSString, cost: Int(properties.fileSize ?? 1024))
        
        logger.info("Image analysis completed in \(result.processingTime) seconds")
        return result
    }
    
    /// Generate a natural language description of the image
    func generateImageDescription(from result: AnalysisResult) -> String {
        var description = ""
        
        // Start with basic image info
        description += "This is a \(result.imageProperties.width)x\(result.imageProperties.height) image. "
        
        // Add main classifications
        if !result.classifications.isEmpty {
            let topClasses = result.classifications.prefix(3)
                .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
                .joined(separator: ", ")
            description += "The image shows: \(topClasses). "
        }
        
        // Add text content
        if !result.extractedText.isEmpty {
            let wordCount = result.extractedText.split(separator: " ").count
            description += "There is text visible containing \(wordCount) words. "
            
            // Include preview if short enough
            if result.extractedText.count < 100 {
                description += "The text reads: \"\(result.extractedText)\". "
            } else {
                let preview = String(result.extractedText.prefix(97)) + "..."
                description += "The text begins with: \"\(preview)\". "
            }
        }
        
        // Add object detection
        if !result.detectedObjects.isEmpty {
            let objectTypes = Dictionary(grouping: result.detectedObjects) { $0.labels.first?.identifier ?? "unknown" }
            let objectSummary = objectTypes.map { "\($0.value.count) \($0.key)" }.joined(separator: ", ")
            description += "I can see \(objectSummary) in the image. "
        }
        
        // Add face information
        if result.faceCount > 0 {
            description += "There \(result.faceCount == 1 ? "is" : "are") \(result.faceCount) \(result.faceCount == 1 ? "person" : "people") visible. "
        }
        
        // Add composition analysis
        if !result.salientRegions.isEmpty {
            description += "The main focus areas are "
            let positions = result.salientRegions.map { rect in
                describePosition(of: rect)
            }.joined(separator: " and ")
            description += positions + ". "
        }
        
        // Add color information
        if !result.dominantColors.isEmpty {
            let colorNames = result.dominantColors.prefix(3)
                .map { describeColor($0) }
                .joined(separator: ", ")
            description += "The dominant colors are \(colorNames). "
        }
        
        // Add any special findings
        if let sceneInfo = result.additionalInfo["scene_analysis"] as? String {
            description += sceneInfo + " "
        }
        
        return description.trimmingCharacters(in: .whitespaces)
    }
    
    /// Extract only text from an image
    func extractText(from image: NSImage) async throws -> String {
        let result = try await analyzeImage(image, options: AnalysisOptions(
            extractText: true,
            classifyImage: false,
            detectObjects: false,
            detectFaces: false,
            analyzeComposition: false
        ))
        return result.extractedText
    }
    
    /// Classify image contents
    func classifyImage(_ image: NSImage) async throws -> [VNClassificationObservation] {
        let result = try await analyzeImage(image, options: AnalysisOptions(
            extractText: false,
            classifyImage: true,
            detectObjects: false,
            detectFaces: false,
            analyzeComposition: false
        ))
        return result.classifications
    }
    
    /// Check if Vision framework is available
    func isAvailable() async -> Bool {
        return true // Vision is always available on macOS
    }
    
    // MARK: - Private Methods
    
    private func createTextRecognitionRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                self.logger.error("Text recognition error: \(error)")
            }
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "es", "fr", "de", "it", "pt", "zh-Hans", "zh-Hant", "ja", "ko"]
        request.usesLanguageCorrection = true
        
        return request
    }
    
    private func createClassificationRequest() -> VNClassifyImageRequest {
        let request = VNClassifyImageRequest { request, error in
            if let error = error {
                self.logger.error("Classification error: \(error)")
            }
        }
        
        return request
    }
    
    private func createObjectDetectionRequest() -> VNRecognizeAnimalsRequest {
        // Using animal recognition as a proxy for general object detection
        // In a real app, you might use a custom Core ML model
        let request = VNRecognizeAnimalsRequest { request, error in
            if let error = error {
                self.logger.error("Object detection error: \(error)")
            }
        }
        
        return request
    }
    
    private func createFaceDetectionRequest() -> VNDetectFaceRectanglesRequest {
        let request = VNDetectFaceRectanglesRequest { request, error in
            if let error = error {
                self.logger.error("Face detection error: \(error)")
            }
        }
        
        return request
    }
    
    private func createBarcodeDetectionRequest() -> VNDetectBarcodesRequest {
        let request = VNDetectBarcodesRequest { request, error in
            if let error = error {
                self.logger.error("Barcode detection error: \(error)")
            }
        }
        
        request.symbologies = [.qr, .ean13, .ean8, .code128, .pdf417, .aztec]
        
        return request
    }
    
    private func createTextRectangleRequest() -> VNDetectTextRectanglesRequest {
        let request = VNDetectTextRectanglesRequest { request, error in
            if let error = error {
                self.logger.error("Text rectangle detection error: \(error)")
            }
        }
        
        request.reportCharacterBoxes = false
        
        return request
    }
    
    private func createSaliencyRequest() -> VNGenerateObjectnessBasedSaliencyImageRequest {
        let request = VNGenerateObjectnessBasedSaliencyImageRequest { request, error in
            if let error = error {
                self.logger.error("Saliency analysis error: \(error)")
            }
        }
        
        return request
    }
    
    private func createHorizonRequest() -> VNDetectHorizonRequest {
        let request = VNDetectHorizonRequest { request, error in
            if let error = error {
                self.logger.error("Horizon detection error: \(error)")
            }
        }
        
        return request
    }
    
    private struct ProcessingResults {
        var extractedText = ""
        var classifications: [VNClassificationObservation] = []
        var detectedObjects: [VNRecognizedObjectObservation] = []
        var faces: [FaceDetail] = []
        var barcodes: [BarcodeInfo] = []
        var textRectangles: [CGRect] = []
        var salientRegions: [CGRect] = []
        var horizon: HorizonInfo?
    }
    
    private func processRequests(_ requests: [VNRequest], on cgImage: CGImage, totalCount: Int) async throws -> ProcessingResults {
        var results = ProcessingResults()
        
        // Process on background queue
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessingResults, Error>) in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AnalysisError.processingFailed("Service deallocated"))
                    return
                }
                
                do {
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try handler.perform(requests)
                    
                    var processedCount = 0
                    
                    // Process results from each request
                    for request in requests {
                        processedCount += 1
                        
                        // Update progress on main thread
                        DispatchQueue.main.async {
                            self.processingProgress = Double(processedCount) / Double(totalCount)
                        }
                        
                        switch request {
                        case let textRequest as VNRecognizeTextRequest:
                            results.extractedText = self.processTextResultsSync(textRequest.results)
                            
                        case let classifyRequest as VNClassifyImageRequest:
                            results.classifications = classifyRequest.results ?? []
                            
                        case let animalRequest as VNRecognizeAnimalsRequest:
                            results.detectedObjects = animalRequest.results ?? []
                            
                        case let faceRequest as VNDetectFaceRectanglesRequest:
                            results.faces = self.processFaceResultsSync(faceRequest.results)
                            
                        case let barcodeRequest as VNDetectBarcodesRequest:
                            results.barcodes = self.processBarcodeResultsSync(barcodeRequest.results)
                            
                        case let textRectRequest as VNDetectTextRectanglesRequest:
                            results.textRectangles = textRectRequest.results?.map { $0.boundingBox } ?? []
                            
                        case let saliencyRequest as VNGenerateObjectnessBasedSaliencyImageRequest:
                            results.salientRegions = self.processSaliencyResultsSync(saliencyRequest.results)
                            
                        case let horizonRequest as VNDetectHorizonRequest:
                            results.horizon = self.processHorizonResultsSync(horizonRequest.results)
                            
                        default:
                            break
                        }
                    }
                    
                    continuation.resume(returning: results)
                    
                } catch {
                    continuation.resume(throwing: AnalysisError.processingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // Sync versions for background processing
    private func processTextResultsSync(_ observations: [VNRecognizedTextObservation]?) -> String {
        guard let observations = observations else { return "" }
        
        return observations
            .compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            .joined(separator: " ")
    }
    
    private func processFaceResultsSync(_ observations: [VNFaceObservation]?) -> [FaceDetail] {
        guard let observations = observations else { return [] }
        
        return observations.map { face in
            FaceDetail(
                boundingBox: face.boundingBox,
                landmarks: face.landmarks,
                confidence: face.confidence,
                attributes: [
                    "hasSmile": face.faceCaptureQuality ?? 0,
                    "yaw": face.yaw?.doubleValue ?? 0,
                    "pitch": face.pitch?.doubleValue ?? 0,
                    "roll": face.roll?.doubleValue ?? 0
                ]
            )
        }
    }
    
    private func processBarcodeResultsSync(_ observations: [VNBarcodeObservation]?) -> [BarcodeInfo] {
        guard let observations = observations else { return [] }
        
        return observations.compactMap { barcode in
            BarcodeInfo(
                symbology: barcode.symbology,
                payloadString: barcode.payloadStringValue,
                boundingBox: barcode.boundingBox
            )
        }
    }
    
    private func processSaliencyResultsSync(_ observations: [VNSaliencyImageObservation]?) -> [CGRect] {
        guard let observations = observations,
              let saliency = observations.first else { return [] }
        
        return saliency.salientObjects?.map { $0.boundingBox } ?? []
    }
    
    private func processHorizonResultsSync(_ observations: [VNHorizonObservation]?) -> HorizonInfo? {
        guard let horizon = observations?.first else { return nil }
        
        return HorizonInfo(
            angle: horizon.angle,
            confidence: horizon.confidence
        )
    }
    
    // Original MainActor versions
    private func processTextResults(_ observations: [VNRecognizedTextObservation]?) -> String {
        guard let observations = observations else { return "" }
        
        return observations
            .compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            .joined(separator: " ")
    }
    
    private func processFaceResults(_ observations: [VNFaceObservation]?) -> [FaceDetail] {
        guard let observations = observations else { return [] }
        
        return observations.map { face in
            FaceDetail(
                boundingBox: face.boundingBox,
                landmarks: face.landmarks,
                confidence: face.confidence,
                attributes: [
                    "hasSmile": face.faceCaptureQuality ?? 0,
                    "yaw": face.yaw?.doubleValue ?? 0,
                    "pitch": face.pitch?.doubleValue ?? 0,
                    "roll": face.roll?.doubleValue ?? 0
                ]
            )
        }
    }
    
    private func processBarcodeResults(_ observations: [VNBarcodeObservation]?) -> [BarcodeInfo] {
        guard let observations = observations else { return [] }
        
        return observations.compactMap { barcode in
            BarcodeInfo(
                symbology: barcode.symbology,
                payloadString: barcode.payloadStringValue,
                boundingBox: barcode.boundingBox
            )
        }
    }
    
    private func processSaliencyResults(_ observations: [VNSaliencyImageObservation]?) -> [CGRect] {
        guard let observations = observations,
              let saliency = observations.first else { return [] }
        
        return saliency.salientObjects?.map { $0.boundingBox } ?? []
    }
    
    private func processHorizonResults(_ observations: [VNHorizonObservation]?) -> HorizonInfo? {
        guard let horizon = observations?.first else { return nil }
        
        return HorizonInfo(
            angle: horizon.angle,
            confidence: horizon.confidence
        )
    }
    
    private func extractImageProperties(from image: NSImage) -> ImageProperties {
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        
        // Get more properties if available
        var hasAlpha = false
        var colorSpace = "Unknown"
        
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            hasAlpha = cgImage.alphaInfo != .none
            colorSpace = cgImage.colorSpace?.name as String? ?? "Unknown"
        }
        
        return ImageProperties(
            width: width,
            height: height,
            orientation: .up,
            hasAlpha: hasAlpha,
            colorSpace: colorSpace,
            fileSize: nil
        )
    }
    
    private func extractDominantColors(from cgImage: CGImage, count: Int = 5) -> [NSColor] {
        // Simple color extraction using Core Image
        let ciImage = CIImage(cgImage: cgImage)
        
        let extentVector = CIVector(x: ciImage.extent.origin.x,
                                   y: ciImage.extent.origin.y,
                                   z: ciImage.extent.size.width,
                                   w: ciImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage"),
              let outputImage = filter.outputImage else { return [] }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(extentVector, forKey: kCIInputExtentKey)
        
        // Get average color
        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: nil)
        
        let avgColor = NSColor(
            red: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: CGFloat(bitmap[3]) / 255.0
        )
        
        // For now, return just the average color
        // A more sophisticated implementation would sample multiple regions
        return [avgColor]
    }
    
    private func buildAdditionalInfo(from results: ProcessingResults, options: AnalysisOptions) -> [String: Any] {
        var info: [String: Any] = [:]
        
        // Add scene analysis based on classifications
        if !results.classifications.isEmpty {
            info["scene_analysis"] = generateSceneAnalysis(from: results.classifications)
        }
        
        // Add text analysis
        if !results.extractedText.isEmpty {
            info["text_word_count"] = results.extractedText.split(separator: " ").count
            info["text_language"] = detectLanguage(in: results.extractedText)
        }
        
        // Add face analysis
        if !results.faces.isEmpty {
            info["face_analysis"] = analyzeFaces(results.faces)
        }
        
        return info
    }
    
    private func generateSceneAnalysis(from classifications: [VNClassificationObservation]) -> String {
        let topClasses = classifications.prefix(5)
        
        // Categorize classifications
        let outdoorKeywords = ["outdoor", "nature", "landscape", "sky", "mountain", "beach", "forest"]
        let indoorKeywords = ["indoor", "room", "interior", "furniture", "office", "home"]
        let peopleKeywords = ["person", "people", "crowd", "portrait", "face"]
        let foodKeywords = ["food", "meal", "dish", "cuisine", "restaurant"]
        
        var isOutdoor = false
        var isIndoor = false
        var hasPeople = false
        var hasFood = false
        
        for classification in topClasses {
            let id = classification.identifier.lowercased()
            if outdoorKeywords.contains(where: { id.contains($0) }) { isOutdoor = true }
            if indoorKeywords.contains(where: { id.contains($0) }) { isIndoor = true }
            if peopleKeywords.contains(where: { id.contains($0) }) { hasPeople = true }
            if foodKeywords.contains(where: { id.contains($0) }) { hasFood = true }
        }
        
        var analysis = "This appears to be "
        
        if isOutdoor {
            analysis += "an outdoor scene"
        } else if isIndoor {
            analysis += "an indoor setting"
        } else {
            analysis += "a photograph"
        }
        
        if hasPeople {
            analysis += " with people"
        }
        
        if hasFood {
            analysis += " featuring food"
        }
        
        analysis += "."
        
        return analysis
    }
    
    private func detectLanguage(in text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        if let language = recognizer.dominantLanguage {
            return language.rawValue
        }
        
        return "unknown"
    }
    
    private func analyzeFaces(_ faces: [FaceDetail]) -> String {
        if faces.count == 1 {
            return "One person is visible in the image"
        } else {
            return "\(faces.count) people are visible in the image"
        }
    }
    
    private func imageCacheKey(_ image: NSImage) -> String {
        // Create a simple hash based on image size and some pixel data
        let size = "\(Int(image.size.width))x\(Int(image.size.height))"
        return "image_\(size)_\(image.hash)"
    }
    
    private func describePosition(of rect: CGRect) -> String {
        let centerX = rect.midX
        let centerY = rect.midY
        
        var position = ""
        
        // Vertical position
        if centerY < 0.33 {
            position += "at the top"
        } else if centerY > 0.67 {
            position += "at the bottom"
        } else {
            position += "in the middle"
        }
        
        // Horizontal position
        if centerX < 0.33 {
            position += " left"
        } else if centerX > 0.67 {
            position += " right"
        } else if !position.contains("middle") {
            position += " center"
        }
        
        return position
    }
    
    private func describeColor(_ color: NSColor) -> String {
        // Convert to RGB for analysis
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return "unknown" }
        
        let r = rgb.redComponent
        let g = rgb.greenComponent
        let b = rgb.blueComponent
        
        // Simple color naming based on RGB values
        if r > 0.8 && g < 0.3 && b < 0.3 { return "red" }
        if r < 0.3 && g > 0.8 && b < 0.3 { return "green" }
        if r < 0.3 && g < 0.3 && b > 0.8 { return "blue" }
        if r > 0.8 && g > 0.8 && b < 0.3 { return "yellow" }
        if r > 0.8 && g < 0.3 && b > 0.8 { return "magenta" }
        if r < 0.3 && g > 0.8 && b > 0.8 { return "cyan" }
        if r > 0.8 && g > 0.5 && b < 0.3 { return "orange" }
        if r > 0.5 && g < 0.3 && b > 0.5 { return "purple" }
        if r > 0.7 && g > 0.7 && b > 0.7 { return "light gray" }
        if r < 0.3 && g < 0.3 && b < 0.3 { return "dark gray" }
        if r > 0.4 && g > 0.2 && b < 0.2 { return "brown" }
        
        return "mixed colors"
    }
}

// MARK: - NaturalLanguage Import

import NaturalLanguage