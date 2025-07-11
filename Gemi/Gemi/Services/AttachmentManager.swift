import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

/// Manages multimodal attachments for chat messages
@MainActor
final class AttachmentManager: ObservableObject {
    static let shared = AttachmentManager()
    
    // MARK: - Types
    
    enum AttachmentType: Equatable {
        case image(NSImage)
        case audio(URL)
        case document(URL)
        
        var icon: String {
            switch self {
            case .image: return "photo"
            case .audio: return "waveform"
            case .document: return "doc"
            }
        }
        
        var typeName: String {
            switch self {
            case .image: return "Image"
            case .audio: return "Audio"
            case .document: return "Document"
            }
        }
    }
    
    struct Attachment: Identifiable {
        let id = UUID()
        let type: AttachmentType
        let url: URL?
        let base64Data: String?
        let thumbnail: NSImage?
        let fileName: String
        let fileSize: Int64
        let createdAt = Date()
        
        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }
    }
    
    enum AttachmentError: LocalizedError {
        case unsupportedType
        case fileTooLarge(maxSize: Int64)
        case encodingFailed
        case readFailed
        
        var errorDescription: String? {
            switch self {
            case .unsupportedType:
                return "This file type is not supported"
            case .fileTooLarge(let maxSize):
                return "File is too large. Maximum size is \(ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file))"
            case .encodingFailed:
                return "Failed to process the attachment"
            case .readFailed:
                return "Could not read the file"
            }
        }
    }
    
    // MARK: - Properties
    
    @Published var attachments: [Attachment] = []
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    @Published var error: AttachmentError?
    
    // Configuration
    private let maxImageSize: Int64 = 20 * 1024 * 1024 // 20MB
    private let maxAudioSize: Int64 = 50 * 1024 * 1024 // 50MB
    private let maxDocumentSize: Int64 = 10 * 1024 * 1024 // 10MB
    private let thumbnailSize = CGSize(width: 200, height: 200)
    
    // Supported types
    private let supportedImageTypes: Set<UTType> = [.png, .jpeg, .gif, .heif, .webP, .bmp, .tiff]
    private let supportedAudioTypes: Set<UTType> = [.mp3, .mpeg4Audio, .wav, .aiff, .audio]
    private let supportedDocumentTypes: Set<UTType> = [.pdf, .text, .plainText, .rtf, .sourceCode]
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Add an attachment from a file URL
    func addAttachment(from url: URL) async throws {
        isProcessing = true
        processingProgress = 0
        defer { isProcessing = false }
        
        // Get file info
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        let fileName = url.lastPathComponent
        
        // Determine file type
        guard let typeIdentifier = UTType(filenameExtension: url.pathExtension) else {
            throw AttachmentError.unsupportedType
        }
        
        // Process based on type
        if supportedImageTypes.contains(typeIdentifier) {
            try await addImageAttachment(from: url, fileName: fileName, fileSize: fileSize)
        } else if supportedAudioTypes.contains(typeIdentifier) {
            try await addAudioAttachment(from: url, fileName: fileName, fileSize: fileSize)
        } else if supportedDocumentTypes.contains(typeIdentifier) {
            try await addDocumentAttachment(from: url, fileName: fileName, fileSize: fileSize)
        } else {
            throw AttachmentError.unsupportedType
        }
    }
    
    /// Add an image directly
    func addImage(_ image: NSImage, fileName: String = "Image.png") async throws {
        isProcessing = true
        processingProgress = 0
        defer { isProcessing = false }
        
        // Convert to data
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw AttachmentError.encodingFailed
        }
        
        let fileSize = Int64(pngData.count)
        
        // Check size
        guard fileSize <= maxImageSize else {
            throw AttachmentError.fileTooLarge(maxSize: maxImageSize)
        }
        
        processingProgress = 0.5
        
        // Create base64
        let base64String = pngData.base64EncodedString()
        
        // Create thumbnail
        let thumbnail = createThumbnail(from: image)
        
        processingProgress = 1.0
        
        // Create attachment
        let attachment = Attachment(
            type: .image(image),
            url: nil,
            base64Data: base64String,
            thumbnail: thumbnail,
            fileName: fileName,
            fileSize: fileSize
        )
        
        attachments.append(attachment)
    }
    
    /// Remove an attachment
    func removeAttachment(_ attachment: Attachment) {
        attachments.removeAll { $0.id == attachment.id }
    }
    
    /// Clear all attachments
    func clearAttachments() {
        attachments.removeAll()
    }
    
    /// Get base64 encoded images for AI API
    func getBase64Images() -> [String] {
        attachments.compactMap { attachment in
            switch attachment.type {
            case .image:
                return attachment.base64Data
            default:
                return nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func addImageAttachment(from url: URL, fileName: String, fileSize: Int64) async throws {
        // Check size
        guard fileSize <= maxImageSize else {
            throw AttachmentError.fileTooLarge(maxSize: maxImageSize)
        }
        
        processingProgress = 0.2
        
        // Load image
        guard let image = NSImage(contentsOf: url) else {
            throw AttachmentError.readFailed
        }
        
        processingProgress = 0.4
        
        // Read data for base64
        guard let data = try? Data(contentsOf: url) else {
            throw AttachmentError.readFailed
        }
        
        processingProgress = 0.6
        
        // Create base64
        let base64String = data.base64EncodedString()
        
        processingProgress = 0.8
        
        // Create thumbnail
        let thumbnail = createThumbnail(from: image)
        
        processingProgress = 1.0
        
        // Create attachment
        let attachment = Attachment(
            type: .image(image),
            url: url,
            base64Data: base64String,
            thumbnail: thumbnail,
            fileName: fileName,
            fileSize: fileSize
        )
        
        attachments.append(attachment)
    }
    
    private func addAudioAttachment(from url: URL, fileName: String, fileSize: Int64) async throws {
        // Check size
        guard fileSize <= maxAudioSize else {
            throw AttachmentError.fileTooLarge(maxSize: maxAudioSize)
        }
        
        processingProgress = 0.5
        
        // For now, just store the reference
        // In the future, we could generate waveforms, transcribe, etc.
        let attachment = Attachment(
            type: .audio(url),
            url: url,
            base64Data: nil,
            thumbnail: nil,
            fileName: fileName,
            fileSize: fileSize
        )
        
        processingProgress = 1.0
        
        attachments.append(attachment)
    }
    
    private func addDocumentAttachment(from url: URL, fileName: String, fileSize: Int64) async throws {
        // Check size
        guard fileSize <= maxDocumentSize else {
            throw AttachmentError.fileTooLarge(maxSize: maxDocumentSize)
        }
        
        processingProgress = 0.5
        
        // For now, just store the reference
        let attachment = Attachment(
            type: .document(url),
            url: url,
            base64Data: nil,
            thumbnail: nil,
            fileName: fileName,
            fileSize: fileSize
        )
        
        processingProgress = 1.0
        
        attachments.append(attachment)
    }
    
    private func createThumbnail(from image: NSImage) -> NSImage? {
        let targetSize = thumbnailSize
        
        // Calculate aspect ratio
        let originalSize = image.size
        let widthRatio = targetSize.width / originalSize.width
        let heightRatio = targetSize.height / originalSize.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(
            width: originalSize.width * ratio,
            height: originalSize.height * ratio
        )
        
        // Create thumbnail
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        
        thumbnail.unlockFocus()
        
        return thumbnail
    }
}

// MARK: - Audio Recording Extension

extension AttachmentManager {
    /// Audio recording functionality
    @MainActor
    final class AudioRecorder: NSObject, ObservableObject {
        @Published var isRecording = false
        @Published var recordingTime: TimeInterval = 0
        @Published var audioLevels: [Float] = Array(repeating: 0, count: 50)
        
        private var audioRecorder: AVAudioRecorder?
        private var timer: Timer?
        private var levelTimer: Timer?
        private let recordingURL: URL
        
        override init() {
            // Create temp file for recording
            let tempDir = FileManager.default.temporaryDirectory
            self.recordingURL = tempDir.appendingPathComponent("gemi_recording_\(UUID().uuidString).m4a")
            super.init()
        }
        
        func startRecording() async throws {
            // Request permission
            let hasPermission = await AVAudioApplication.requestRecordPermission()
            guard hasPermission else {
                throw NSError(domain: "GemiAudioRecorder", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Microphone permission denied"
                ])
            }
            
            // Note: AVAudioSession is not needed on macOS
            // macOS handles audio permissions differently
            
            // Settings for recording
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // Create recorder
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            
            // Start timers
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    self.recordingTime += 0.1
                }
            }
            
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                Task { @MainActor in
                    self.updateAudioLevels()
                }
            }
        }
        
        func stopRecording() -> URL? {
            audioRecorder?.stop()
            audioRecorder = nil
            
            timer?.invalidate()
            timer = nil
            
            levelTimer?.invalidate()
            levelTimer = nil
            
            isRecording = false
            audioLevels = Array(repeating: 0, count: 50)
            
            // Check if file exists
            if FileManager.default.fileExists(atPath: recordingURL.path) {
                return recordingURL
            }
            
            return nil
        }
        
        private func updateAudioLevels() {
            guard let recorder = audioRecorder else { return }
            
            recorder.updateMeters()
            let level = recorder.averagePower(forChannel: 0)
            let normalizedLevel = pow(10, level / 20) // Convert dB to linear
            
            // Update levels array
            audioLevels.append(normalizedLevel)
            if audioLevels.count > 50 {
                audioLevels.removeFirst()
            }
        }
        
        var formattedTime: String {
            let minutes = Int(recordingTime) / 60
            let seconds = Int(recordingTime) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}