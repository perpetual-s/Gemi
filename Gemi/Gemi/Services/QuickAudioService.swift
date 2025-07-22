import Foundation
import Speech
import AVFoundation
import os.log

/// Streamlined audio transcription service optimized for diary entries
@MainActor
final class QuickAudioService: ObservableObject {
    static let shared = QuickAudioService()
    
    private let logger = Logger(subsystem: "com.gemi", category: "QuickAudio")
    
    enum QuickTranscriptionError: LocalizedError {
        case notAuthorized
        case transcriptionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition not authorized"
            case .transcriptionFailed(let reason):
                return "Transcription failed: \(reason)"
            }
        }
    }
    
    /// Quick transcription focused on getting text fast
    func quickTranscribe(_ audioURL: URL) async throws -> (text: String, duration: TimeInterval) {
        logger.info("Starting quick audio transcription")
        
        // Check authorization
        let authStatus = await requestAuthorization()
        guard authStatus == .authorized else {
            throw QuickTranscriptionError.notAuthorized
        }
        
        // Get duration
        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        // Use system default recognizer (usually user's language)
        guard let recognizer = SFSpeechRecognizer(),
              recognizer.isAvailable else {
            // Fallback to English if system language not available
            guard let englishRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
                  englishRecognizer.isAvailable else {
                throw QuickTranscriptionError.transcriptionFailed("No speech recognizer available")
            }
            return try await performTranscription(with: englishRecognizer, url: audioURL, duration: durationSeconds)
        }
        
        return try await performTranscription(with: recognizer, url: audioURL, duration: durationSeconds)
    }
    
    private func performTranscription(with recognizer: SFSpeechRecognizer, url: URL, duration: TimeInterval) async throws -> (text: String, duration: TimeInterval) {
        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: url)
            
            // Configure for speed
            request.shouldReportPartialResults = false
            request.taskHint = .dictation
            
            // Enable on-device recognition for speed and privacy
            if #available(macOS 13.0, *) {
                request.requiresOnDeviceRecognition = true
            }
            
            // Add punctuation for better readability
            request.addsPunctuation = true
            
            // Set up timeout
            var timeoutTask: Task<Void, Never>?
            
            let recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                timeoutTask?.cancel()
                
                if let error = error {
                    continuation.resume(throwing: QuickTranscriptionError.transcriptionFailed(error.localizedDescription))
                    return
                }
                
                if let result = result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                    continuation.resume(returning: (text: text, duration: duration))
                }
            }
            
            // Set reasonable timeout based on audio duration
            let timeoutDuration = max(duration * 2, 30.0) // 2x duration or 30 seconds, whichever is larger
            
            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeoutDuration * 1_000_000_000))
                recognitionTask.cancel()
                continuation.resume(throwing: QuickTranscriptionError.transcriptionFailed("Transcription timeout"))
            }
        }
    }
    
    private func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    /// Generate simple audio description for diary context
    func generateAudioDescription(text: String, duration: TimeInterval, fileName: String) -> String {
        var description = "Audio recording"
        
        if !fileName.isEmpty {
            description = "'\(fileName)'"
        }
        
        description += String(format: " (%.1f seconds)", duration)
        
        if !text.isEmpty {
            description += ": \"\(text)\""
        } else {
            description += " - no clear speech detected"
        }
        
        return description
    }
}