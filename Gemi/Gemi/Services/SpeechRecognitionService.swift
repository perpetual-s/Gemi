import Foundation
import Speech
import AVFoundation
import SwiftUI

/// SpeechRecognitionService provides local speech-to-text functionality for Gemi.
/// This service uses Apple's on-device Speech framework to maintain privacy by ensuring
/// all speech processing occurs locally without sending audio data to external servers.
///
/// Privacy Features:
/// - On-device speech recognition (no data sent to Apple servers when available)
/// - Microphone access only during active recording
/// - User control over when recording starts and stops
/// - Clear visual feedback during recording state
@Observable
@MainActor
final class SpeechRecognitionService: NSObject {
    
    // MARK: - Properties
    
    /// Current authorization status for speech recognition
    private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    /// Current authorization status for microphone access
    private(set) var microphoneAuthorizationStatus: Bool = false
    
    /// Whether speech recognition is currently active
    private(set) var isRecording: Bool = false
    
    /// Current transcribed text from the ongoing recognition session
    private(set) var currentTranscription: String = ""
    
    /// Error message for displaying to user
    private(set) var errorMessage: String?
    
    /// Whether the service is available and ready to use
    var isAvailable: Bool {
        speechRecognizer?.isAvailable == true && 
        authorizationStatus == .authorized && 
        microphoneAuthorizationStatus == true
    }
    
    // MARK: - Private Properties
    
    /// Speech recognizer instance (configured for on-device recognition when possible)
    private var speechRecognizer: SFSpeechRecognizer?
    
    /// Audio engine for capturing microphone input
    private let audioEngine = AVAudioEngine()
    
    /// Current speech recognition request
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    /// Current speech recognition task
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupSpeechRecognizer()
        checkInitialPermissions()
    }
    
    // MARK: - Setup
    
    /// Sets up the speech recognizer with preference for on-device recognition
    private func setupSpeechRecognizer() {
        // Try to use the user's preferred locale first, fall back to English
        let locale = Locale.current
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        // If no recognizer available for current locale, fall back to English
        if speechRecognizer == nil {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
        
        speechRecognizer?.delegate = self
        
        print("SpeechRecognitionService initialized")
        print("Locale: \(locale.identifier)")
        print("Speech recognizer available: \(speechRecognizer?.isAvailable ?? false)")
    }
    
    /// Checks initial permission states
    private func checkInitialPermissions() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        microphoneAuthorizationStatus = checkMicrophonePermission()
        
        print("Initial speech authorization: \(authorizationStatus.rawValue)")
        print("Initial microphone authorization: \(microphoneAuthorizationStatus)")
    }
    
    /// Checks current microphone permission status on macOS
    private func checkMicrophonePermission() -> Bool {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        return authStatus == .authorized
    }
    
    // MARK: - Permission Management
    
    /// Requests necessary permissions for speech recognition
    func requestPermissions() async {
        // Request speech recognition permission
        let speechStatus = await requestSpeechRecognitionPermission()
        authorizationStatus = speechStatus
        
        // Request microphone permission
        let micStatus = await requestMicrophonePermission()
        microphoneAuthorizationStatus = micStatus
        
        print("Permissions requested - Speech: \(speechStatus), Microphone: \(micStatus)")
    }
    
    /// Requests speech recognition permission
    private func requestSpeechRecognitionPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    /// Requests microphone permission
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Recording Control
    
    /// Starts speech recognition and recording
    func startRecording() async throws {
        guard isAvailable else {
            throw SpeechRecognitionError.notAvailable
        }
        
        guard !isRecording else {
            print("Recording already in progress")
            return
        }
        
        // Stop any existing recording
        stopRecording()
        
        // Configure audio session
        try configureAudioSession()
        
        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request
        
        // Configure request for on-device recognition when available
        if #available(macOS 13.0, *) {
            request.requiresOnDeviceRecognition = true
            request.addsPunctuation = true
        }
        
        // Set up audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install audio tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task
        guard let speechRecognizer = speechRecognizer else {
            throw SpeechRecognitionError.recognizerUnavailable
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }
        
        isRecording = true
        currentTranscription = ""
        errorMessage = nil
        
        print("Started speech recognition")
    }
    
    /// Stops speech recognition and recording
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
        
        print("Stopped speech recognition")
    }
    
    // MARK: - Audio Session Configuration
    
    /// Configures the audio session for recording (macOS-compatible)
    private func configureAudioSession() throws {
        // On macOS, audio session configuration is handled differently
        // The audioEngine will handle most of the configuration automatically
        print("Audio session configured for macOS")
    }
    
    // MARK: - Recognition Result Handling
    
    /// Handles speech recognition results
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            handleRecognitionError(error)
            return
        }
        
        guard let result = result else { return }
        
        // Update current transcription
        currentTranscription = result.bestTranscription.formattedString
        
        // If this is a final result, we can process it
        if result.isFinal {
            print("Final transcription: \(currentTranscription)")
        }
    }
    
    /// Handles speech recognition errors
    private func handleRecognitionError(_ error: Error) {
        print("Speech recognition error: \(error.localizedDescription)")
        
        if let speechError = error as? SpeechRecognitionError {
            errorMessage = speechError.localizedDescription
        } else {
            errorMessage = "Speech recognition failed: \(error.localizedDescription)"
        }
        
        stopRecording()
    }
    
    // MARK: - Transcription Management
    
    /// Returns the current transcription and clears it
    func consumeTranscription() -> String {
        let transcription = currentTranscription
        currentTranscription = ""
        return transcription
    }
    
    /// Clears any error message
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            print("Speech recognizer availability changed: \(available)")
            
            if !available && isRecording {
                stopRecording()
                errorMessage = "Speech recognition became unavailable"
            }
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during speech recognition
enum SpeechRecognitionError: Error, LocalizedError {
    case notAvailable
    case recognizerUnavailable
    case audioEngineError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Speech recognition is not available. Please check permissions and try again."
        case .recognizerUnavailable:
            return "Speech recognizer is not available for your language."
        case .audioEngineError:
            return "Audio recording failed. Please check microphone access."
        case .permissionDenied:
            return "Speech recognition permission is required. Please enable it in System Preferences."
        }
    }
}