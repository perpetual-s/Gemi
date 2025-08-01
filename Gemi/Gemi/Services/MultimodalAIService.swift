import Foundation
import SwiftUI
import Vision
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
    private let lightweightVision = LightweightVisionService.shared
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
        case unsupportedAttachmentType
        
        var errorDescription: String? {
            switch self {
            case .noAttachments:
                return "No attachments to process"
            case .visionProcessingFailed(let reason):
                return "Image analysis failed: \(reason)"
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
    }
    
    // MARK: - Public Methods
    
    /// Process all current attachments and create enhanced context for AI
    func createMultimodalContext(for message: String) async throws -> MultimodalContext {
        logger.info("Creating multimodal context for message with \(self.attachmentManager.attachments.count) attachments")
        
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
        
        // Send completion notification if we processed attachments
        if !processedAttachments.isEmpty {
            let summary = processedAttachments.count == 1 ? 
                "Analyzed 1 attachment" : 
                "Analyzed \(processedAttachments.count) attachments"
            postAnalysisUpdate(summary)
        }
        
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
            // Send initial analysis notification
            postAnalysisUpdate("Starting image analysis...")
            let result = try await processImage(nsImage, attachment: attachment)
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
        
        // Quick analysis for speed
        let quickDescription = try await lightweightVision.quickAnalyze(image)
        
        // Build description
        var description = "I'm looking at "
        
        if !attachment.fileName.isEmpty {
            description += "'\(attachment.fileName)' - "
        }
        
        description += quickDescription
        
        // Try text extraction only if likely to contain text
        if quickDescription.contains("document") || quickDescription.contains("text") || quickDescription.contains("screenshot") {
            if let extractedText = await lightweightVision.quickTextExtraction(image) {
                description += ". The text reads: \"\(extractedText)\""
            }
        }
        
        // Build minimal metadata for speed
        let metadata: [String: Any] = [
            "width": Int(image.size.width),
            "height": Int(image.size.height),
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
    
    // MARK: - Helper Methods
    
    private func postAnalysisUpdate(_ message: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("MultimodalAnalysisUpdate"),
            object: message
        )
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
        // Vision is always available on macOS
        let visionAvailable = true
        // Speech recognition is no longer supported
        let speechAvailable = false
        
        return (vision: visionAvailable, speech: speechAvailable)
    }
    
    /// Get processing statistics
    func getProcessingStats() -> [String: Any] {
        return [
            "totalProcessed": processedAttachmentsCount,
            "averageProcessingTime": averageProcessingTime,
            "supportedTypes": ["image"]
        ]
    }
    
    private var processedAttachmentsCount = 0
    private var totalProcessingTime: TimeInterval = 0
    
    private var averageProcessingTime: TimeInterval {
        guard processedAttachmentsCount > 0 else { return 0 }
        return totalProcessingTime / Double(processedAttachmentsCount)
    }
}