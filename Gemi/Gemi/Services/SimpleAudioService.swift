
import AVFoundation
import Speech
import SwiftUI

@MainActor
final class SimpleAudioService: ObservableObject {
    static let shared = SimpleAudioService()

    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var lastError: String? = nil
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!

    private init() {
        self.authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func startTranscription() {
        isListening = true
        transcribedText = ""
        lastError = nil

        do {
            try setupAndStartAudioEngine()
        } catch {
            self.lastError = error.localizedDescription
            self.isListening = false
        }
    }

    func stopTranscription() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
            }
        }
    }

    private func setupAndStartAudioEngine() throws {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw AudioError.notAuthorized
        }

        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest!.shouldReportPartialResults = true
        recognitionRequest!.requiresOnDeviceRecognition = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
                if result.isFinal {
                    self.stopTranscription()
                }
            } else if let error = error {
                self.lastError = error.localizedDescription
                self.stopTranscription()
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine!.prepare()
        
        do {
            try audioEngine!.start()
        } catch {
            throw AudioError.audioEngineError(error.localizedDescription)
        }
    }

    enum AudioError: LocalizedError {
        case notAuthorized
        case recognizerNotAvailable
        case audioEngineError(String)
    }
}
