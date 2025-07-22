import Foundation
import SwiftUI
import Vision
import Speech
import AVFoundation
import os.log

/// Coordinates multimodal processing for Gemi, converting images and audio to rich text descriptions
@MainActor
final class MultimodalAIService: ObservableObject {
    static let shared = MultimodalAIService()
    
    // MARK: - Published Properties
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    @Published var currentOperation: String = ""
    @Published var lastError: Error?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.gemi", category: "MultimodalAI")
    private let visionService = VisionAnalysisService.shared
    private let speechService = SpeechTranscriptionService.shared
    private let attachmentManager = AttachmentManager.shared
    private let ollamaService = OllamaChatService.shared
    
    // Processing queue for managing concurrent operations
    private let processingQueue = DispatchQueue(label: "com.gemi.multimodal", qos: .userInitiated)
    
    // MARK: - Types
    
    struct ProcessedAttachment {
        let id: UUID
        let originalType: AttachmentManager.AttachmentType
        let textDescription: String
        let metadata: [String: Any]
        let processingTime: TimeInterval
    }
    
    struct MultimodalContext {
        let originalMessage: String
        let processedAttachments: [ProcessedAttachment]
        let enhancedPrompt: String
        let totalProcessingTime: TimeInterval
    }
    
    enum ProcessingError: LocalizedError {
        case noAttachments
        case visionProcessingFailed(String)
        case speechProcessingFailed(String)
        case unsupportedAttachmentType
        
        var errorDescription: String? {
            switch self {
            case .noAttachments:
                return "No attachments to process"
            case .visionProcessingFailed(let reason):
                return "Image analysis failed: \(reason)"
            case .speechProcessingFailed(let reason):
                return "Audio processing failed: \(reason)"
            case .unsupportedAttachmentType:
                return "This attachment type is not supported"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        // Listen for attachment changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(attachmentsDidChange),
            name: NSNotification.Name("AttachmentsDidChange"),
            object: nil
        )
    }
    
    @objc private func attachmentsDidChange() {
        // Could trigger preprocessing here if needed
        logger.debug("Attachments changed, ready for processing")
    }
    
    // MARK: - Public Methods
    
    /// Process all current attachments and create enhanced context for AI
    func createMultimodalContext(for message: String) async throws -> MultimodalContext {
        logger.info("Creating multimodal context for message with \(attachmentManager.attachments.count) attachments")
        
        let startTime = Date()
        isProcessing = true
        processingProgress = 0
        defer { 
            isProcessing = false
            processingProgress = 0
            currentOperation = ""
        }
        
        // Process attachments if any
        var processedAttachments: [ProcessedAttachment] = []
        
        if !attachmentManager.attachments.isEmpty {
            let totalAttachments = Double(attachmentManager.attachments.count)
            
            for (index, attachment) in attachmentManager.attachments.enumerated() {
                currentOperation = "Processing \(attachment.type.typeName) (\(index + 1)/\(Int(totalAttachments)))"
                
                do {
                    let processed = try await processAttachment(attachment)
                    processedAttachments.append(processed)
                    
                    processingProgress = Double(index + 1) / totalAttachments
                } catch {
                    logger.error("Failed to process attachment: \(error)")
                    // Continue with other attachments
                }
            }
        }
        
        // Build enhanced prompt
        let enhancedPrompt = buildEnhancedPrompt(
            originalMessage: message,
            processedAttachments: processedAttachments
        )
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        return MultimodalContext(
            originalMessage: message,
            processedAttachments: processedAttachments,
            enhancedPrompt: enhancedPrompt,
            totalProcessingTime: totalTime
        )
    }
    
    /// Process a single attachment and convert to text description
    private func processAttachment(_ attachment: AttachmentManager.Attachment) async throws -> ProcessedAttachment {
        let startTime = Date()
        
        switch attachment.type {
        case .image(let nsImage):
            let result = try await processImage(nsImage, attachment: attachment)
            return ProcessedAttachment(
                id: attachment.id,
                originalType: attachment.type,
                textDescription: result.description,
                metadata: result.metadata,
                processingTime: Date().timeIntervalSince(startTime)
            )
            
        case .audio(let url):
            let result = try await processAudio(url, attachment: attachment)
            return ProcessedAttachment(
                id: attachment.id,
                originalType: attachment.type,
                textDescription: result.description,
                metadata: result.metadata,
                processingTime: Date().timeIntervalSince(startTime)
            )
            
        case .document(let url):
            let result = try await processDocument(url, attachment: attachment)
            return ProcessedAttachment(
                id: attachment.id,
                originalType: attachment.type,
                textDescription: result.description,
                metadata: result.metadata,
                processingTime: Date().timeIntervalSince(startTime)
            )
        }
    }
    
    // MARK: - Image Processing
    
    private func processImage(_ image: NSImage, attachment: AttachmentManager.Attachment) async throws -> (description: String, metadata: [String: Any]) {
        logger.debug("Processing image: \(attachment.fileName)")
        
        // Perform comprehensive Vision analysis
        let analysisResult = try await visionService.analyzeImage(
            image,
            options: VisionAnalysisService.AnalysisOptions(
                extractText: true,
                classifyImage: true,
                detectObjects: true,
                detectFaces: true,
                analyzeComposition: true
            )
        )
        
        // Build rich description
        var description = "I'm looking at an image"
        
        // Add file info
        if !attachment.fileName.isEmpty {
            description += " (file: '\(attachment.fileName)')"
        }
        
        description += ". "
        
        // Add classifications
        if !analysisResult.classifications.isEmpty {
            let topClassifications = analysisResult.classifications
                .prefix(3)
                .map { $0.identifier }
                .joined(separator: ", ")
            description += "The image contains: \(topClassifications). "
        }
        
        // Add detected text
        if !analysisResult.extractedText.isEmpty {
            description += "I can see text in the image that reads: \"\(analysisResult.extractedText)\". "
        }
        
        // Add object detection results
        if !analysisResult.detectedObjects.isEmpty {
            description += "I detected \(analysisResult.detectedObjects.count) distinct object(s) in the scene. "
        }
        
        // Add face detection
        if analysisResult.faceCount > 0 {
            description += "There are \(analysisResult.faceCount) face(s) visible. "
        }
        
        // Add scene analysis
        if let sceneAnalysis = analysisResult.additionalInfo["scene_analysis"] as? String {
            description += sceneAnalysis + " "
        }
        
        // Build metadata
        var metadata: [String: Any] = [
            "width": image.size.width,
            "height": image.size.height,
            "hasText": !analysisResult.extractedText.isEmpty,
            "objectCount": analysisResult.detectedObjects.count,
            "faceCount": analysisResult.faceCount,
            "topClassification": analysisResult.classifications.first?.identifier ?? "unknown"
        ]
        
        if analysisResult.dominantColors.count > 0 {
            metadata["dominantColors"] = analysisResult.dominantColors
        }
        
        return (description: description.trimmingCharacters(in: .whitespaces), metadata: metadata)
    }
    
    // MARK: - Audio Processing
    
    private func processAudio(_ url: URL, attachment: AttachmentManager.Attachment) async throws -> (description: String, metadata: [String: Any]) {
        logger.debug("Processing audio: \(attachment.fileName)")
        
        // Get audio duration
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        
        // Transcribe audio
        let transcriptionResult = try await speechService.transcribeAudioFile(
            url: url,
            options: SpeechTranscriptionService.TranscriptionOptions(
                language: .automatic,
                includeTimestamps: true,
                includeConfidence: true,
                includePunctuation: true
            )
        )
        
        // Build description
        var description = "I'm listening to an audio recording"
        
        if !attachment.fileName.isEmpty {
            description += " (file: '\(attachment.fileName)')"
        }
        
        description += String(format: " that is %.1f seconds long. ", duration)
        
        // Add transcription
        if !transcriptionResult.text.isEmpty {
            description += "Here's what I heard: \"\(transcriptionResult.text)\" "
            
            // Add speaking rate if available
            if let speakingRate = transcriptionResult.metadata["speakingRate"] as? Double {
                description += String(format: "(speaking rate: %.0f words/minute) ", speakingRate)
            }
            
            // Add detected emotion or tone if we implement it
            if let tone = analyzeAudioTone(from: transcriptionResult) {
                description += "The speaker sounds \(tone). "
            }
        } else {
            description += "I couldn't transcribe any clear speech from this audio. "
        }
        
        // Build metadata
        let metadata: [String: Any] = [
            "duration": duration,
            "format": url.pathExtension,
            "hasTranscription": !transcriptionResult.text.isEmpty,
            "language": transcriptionResult.detectedLanguage ?? "unknown",
            "confidence": transcriptionResult.averageConfidence
        ]
        
        return (description: description.trimmingCharacters(in: .whitespaces), metadata: metadata)
    }
    
    // MARK: - Document Processing
    
    private func processDocument(_ url: URL, attachment: AttachmentManager.Attachment) async throws -> (description: String, metadata: [String: Any]) {
        logger.debug("Processing document: \(attachment.fileName)")
        
        // For now, basic document info
        // In the future, could use PDFKit or other frameworks
        var description = "I see a document"
        
        if !attachment.fileName.isEmpty {
            description += " titled '\(attachment.fileName)'"
        }
        
        let fileExtension = url.pathExtension.lowercased()
        description += " (.\(fileExtension) file, \(attachment.formattedSize)). "
        
        // Add type-specific handling
        switch fileExtension {
        case "pdf":
            description += "This is a PDF document. "
        case "txt", "md":
            // Try to read text content
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let preview = String(content.prefix(200))
                description += "The document begins with: \"\(preview)...\" "
            }
        case "rtf":
            description += "This is a rich text document. "
        default:
            description += "This is a \(fileExtension.uppercased()) document. "
        }
        
        let metadata: [String: Any] = [
            "fileType": fileExtension,
            "fileSize": attachment.fileSize,
            "fileName": attachment.fileName
        ]
        
        return (description: description.trimmingCharacters(in: .whitespaces), metadata: metadata)
    }
    
    // MARK: - Prompt Building
    
    private func buildEnhancedPrompt(originalMessage: String, processedAttachments: [ProcessedAttachment]) -> String {
        if processedAttachments.isEmpty {
            return originalMessage
        }
        
        var enhancedPrompt = ""
        
        // Add attachment context
        enhancedPrompt += "[Context: I'm sharing "
        
        let attachmentTypes = processedAttachments.map { attachment in
            switch attachment.originalType {
            case .image: return "an image"
            case .audio: return "an audio recording"
            case .document: return "a document"
            }
        }
        
        if attachmentTypes.count == 1 {
            enhancedPrompt += attachmentTypes[0]
        } else {
            enhancedPrompt += "\(attachmentTypes.count) items"
        }
        
        enhancedPrompt += " with you.]\n\n"
        
        // Add detailed descriptions
        for (index, processed) in processedAttachments.enumerated() {
            if processedAttachments.count > 1 {
                enhancedPrompt += "Item \(index + 1): "
            }
            enhancedPrompt += processed.textDescription + "\n\n"
        }
        
        // Add original message
        enhancedPrompt += "My message: " + originalMessage
        
        return enhancedPrompt
    }
    
    // MARK: - Audio Tone Analysis
    
    private func analyzeAudioTone(from transcription: SpeechTranscriptionService.TranscriptionResult) -> String? {
        // Simple heuristic based on speaking rate and pauses
        // In a real implementation, could use more sophisticated audio analysis
        
        guard let speakingRate = transcription.metadata["speakingRate"] as? Double else {
            return nil
        }
        
        if speakingRate > 180 {
            return "hurried or anxious"
        } else if speakingRate < 100 {
            return "calm or thoughtful"
        } else if transcription.text.contains("!") || transcription.text.contains("?!") {
            return "excited or emphatic"
        }
        
        return nil
    }
    
    // MARK: - Chat Integration
    
    /// Send a multimodal message through the chat service
    func sendMultimodalMessage(_ message: String) -> AsyncThrowingStream<OllamaChatService.ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Process attachments first
                    let context = try await createMultimodalContext(for: message)
                    
                    // Clear attachments after processing
                    await MainActor.run {
                        attachmentManager.clearAttachments()
                    }
                    
                    // Create chat request with enhanced prompt
                    let request = OllamaChatService.ChatRequest(
                        messages: [
                            OllamaChatService.ChatMessage(
                                role: "user",
                                content: context.enhancedPrompt,
                                images: nil // Already processed into text
                            )
                        ],
                        model: "gemma3n:latest",
                        stream: true,
                        options: nil
                    )
                    
                    // Stream responses
                    for try await response in try await ollamaService.chat(request) {
                        continuation.yield(response)
                        
                        if response.done {
                            continuation.finish()
                            break
                        }
                    }
                } catch {
                    lastError = error
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Check if multimodal processing is available
    func checkAvailability() async -> (vision: Bool, speech: Bool) {
        let visionAvailable = await visionService.isAvailable()
        let speechAvailable = speechService.isAvailable()
        
        return (vision: visionAvailable, speech: speechAvailable)
    }
    
    /// Get processing statistics
    func getProcessingStats() -> [String: Any] {
        return [
            "totalProcessed": processedAttachmentsCount,
            "averageProcessingTime": averageProcessingTime,
            "supportedTypes": ["image", "audio", "document"]
        ]
    }
    
    private var processedAttachmentsCount = 0
    private var totalProcessingTime: TimeInterval = 0
    
    private var averageProcessingTime: TimeInterval {
        guard processedAttachmentsCount > 0 else { return 0 }
        return totalProcessingTime / Double(processedAttachmentsCount)
    }
}

// MARK: - Supporting Services

@MainActor
final class VisionAnalysisService: ObservableObject {
    static let shared = VisionAnalysisService()
    
    struct AnalysisOptions {
        var extractText = true
        var classifyImage = true
        var detectObjects = true
        var detectFaces = false
        var analyzeComposition = false
    }
    
    struct AnalysisResult {
        let extractedText: String
        let classifications: [VNClassificationObservation]
        let detectedObjects: [VNRecognizedObjectObservation]
        let faceCount: Int
        let dominantColors: [NSColor]
        let additionalInfo: [String: Any]
    }
    
    func analyzeImage(_ image: NSImage, options: AnalysisOptions = AnalysisOptions()) async throws -> AnalysisResult {
        // Placeholder - would implement full Vision framework integration
        return AnalysisResult(
            extractedText: "",
            classifications: [],
            detectedObjects: [],
            faceCount: 0,
            dominantColors: [],
            additionalInfo: [:]
        )
    }
    
    func isAvailable() async -> Bool {
        return true
    }
}

@MainActor
final class SpeechTranscriptionService: ObservableObject {
    static let shared = SpeechTranscriptionService()
    
    struct TranscriptionOptions {
        enum Language {
            case automatic
            case specific(Locale)
        }
        
        var language: Language = .automatic
        var includeTimestamps = false
        var includeConfidence = false
        var includePunctuation = true
    }
    
    struct TranscriptionResult {
        let text: String
        let segments: [TranscriptionSegment]
        let detectedLanguage: String?
        let averageConfidence: Float
        let metadata: [String: Any]
    }
    
    struct TranscriptionSegment {
        let text: String
        let timestamp: TimeInterval
        let duration: TimeInterval
        let confidence: Float
    }
    
    func transcribeAudioFile(url: URL, options: TranscriptionOptions = TranscriptionOptions()) async throws -> TranscriptionResult {
        // Placeholder - would implement full Speech framework integration
        return TranscriptionResult(
            text: "",
            segments: [],
            detectedLanguage: "en-US",
            averageConfidence: 0.95,
            metadata: [:]
        )
    }
    
    func isAvailable() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }
}