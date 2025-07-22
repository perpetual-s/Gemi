import Foundation
import Speech
import AVFoundation
import os.log

/// Comprehensive Speech framework service for transcribing audio locally
@MainActor
final class SpeechTranscriptionService: ObservableObject {
    static let shared = SpeechTranscriptionService()
    
    
    // MARK: - Published Properties
    
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0
    @Published var currentSegment = ""
    @Published var lastError: Error?
    @Published var availableLanguages: [Locale] = []
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.gemi", category: "SpeechTranscription")
    private var recognizers: [String: SFSpeechRecognizer] = [:]
    private var currentTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    // Cache for recent transcriptions
    private var transcriptionCache = NSCache<NSURL, CachedTranscription>()
    
    // MARK: - Types
    
    struct TranscriptionOptions {
        enum Language {
            case automatic
            case specific(Locale)
        }
        
        var language: Language = .automatic
        var includeTimestamps = true
        var includeConfidence = true
        var includePunctuation = true
        var includeAlternatives = false
        var maxAlternatives = 3
        var shouldReportPartialResults = true
        var taskHint: SFSpeechRecognitionTaskHint = .dictation
    }
    
    struct TranscriptionResult {
        let text: String
        let segments: [TranscriptionSegment]
        let detectedLanguage: String?
        let averageConfidence: Float
        let speakingRate: Double
        let metadata: [String: Any]
        let alternatives: [[TranscriptionSegment]]
        let processingTime: TimeInterval
    }
    
    struct TranscriptionSegment {
        let text: String
        let timestamp: TimeInterval
        let duration: TimeInterval
        let confidence: Float
        let alternativeInterpretations: [String]
    }
    
    private class CachedTranscription {
        let result: TranscriptionResult
        let timestamp: Date
        
        init(result: TranscriptionResult) {
            self.result = result
            self.timestamp = Date()
        }
    }
    
    enum TranscriptionError: LocalizedError {
        case notAuthorized
        case recognizerNotAvailable
        case audioFileNotFound
        case processingFailed(String)
        case languageNotSupported
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition not authorized. Please grant permission in System Preferences."
            case .recognizerNotAvailable:
                return "Speech recognizer is not available"
            case .audioFileNotFound:
                return "Audio file not found"
            case .processingFailed(let reason):
                return "Transcription failed: \(reason)"
            case .languageNotSupported:
                return "The detected language is not supported"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        transcriptionCache.countLimit = 20
        transcriptionCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        
        setupAvailableLanguages()
    }
    
    private func setupAvailableLanguages() {
        // Get all supported locales
        let supportedLocales = SFSpeechRecognizer.supportedLocales()
        
        // Filter for commonly used languages that Gemma supports
        let preferredLanguages = [
            "en-US", "en-GB", "en-AU", "en-IN",  // English variants
            "es-ES", "es-MX", "es-US",           // Spanish variants
            "fr-FR", "fr-CA",                    // French variants
            "de-DE", "de-CH",                    // German variants
            "it-IT",                             // Italian
            "pt-BR", "pt-PT",                    // Portuguese variants
            "zh-CN", "zh-TW", "zh-HK",          // Chinese variants
            "ja-JP",                             // Japanese
            "ko-KR",                             // Korean
            "ru-RU",                             // Russian
            "ar-SA",                             // Arabic
            "hi-IN",                             // Hindi
            "nl-NL",                             // Dutch
            "sv-SE",                             // Swedish
            "da-DK",                             // Danish
            "no-NO",                             // Norwegian
            "fi-FI",                             // Finnish
            "pl-PL",                             // Polish
            "tr-TR",                             // Turkish
            "he-IL",                             // Hebrew
            "th-TH",                             // Thai
            "vi-VN",                             // Vietnamese
            "id-ID",                             // Indonesian
            "ms-MY"                              // Malay
        ]
        
        availableLanguages = supportedLocales.filter { locale in
            preferredLanguages.contains(locale.identifier)
        }.sorted { $0.identifier < $1.identifier }
        
        // Pre-initialize recognizers for better performance
        for locale in availableLanguages {
            recognizers[locale.identifier] = SFSpeechRecognizer(locale: locale)
        }
        
        logger.info("Initialized support for \(self.availableLanguages.count) languages")
    }
    
    // MARK: - Public Methods
    
    /// Transcribe an audio file with specified options
    func transcribeAudioFile(url: URL, options: TranscriptionOptions = TranscriptionOptions()) async throws -> TranscriptionResult {
        logger.info("Starting audio transcription for: \(url.lastPathComponent)")
        
        let startTime = Date()
        isTranscribing = true
        transcriptionProgress = 0
        defer {
            isTranscribing = false
            transcriptionProgress = 0
            currentSegment = ""
        }
        
        // Check cache first
        if let cached = transcriptionCache.object(forKey: url as NSURL) {
            logger.debug("Returning cached transcription")
            return cached.result
        }
        
        // Check authorization
        let authStatus = await requestAuthorization()
        guard authStatus == .authorized else {
            throw TranscriptionError.notAuthorized
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TranscriptionError.audioFileNotFound
        }
        
        // Get audio duration for progress tracking
        let duration = try await getAudioDuration(url: url)
        
        // Determine language
        let locale = try await determineLanguage(for: url, preference: options.language)
        
        // Get or create recognizer
        guard let recognizer = getRecognizer(for: locale),
              recognizer.isAvailable else {
            throw TranscriptionError.recognizerNotAvailable
        }
        
        // Create and configure request
        let request = SFSpeechURLRecognitionRequest(url: url)
        configureRequest(request, with: options)
        
        // Perform transcription
        let result = try await performTranscription(
            with: recognizer,
            request: request,
            duration: duration,
            options: options
        )
        
        // Calculate processing time
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Build final result
        let finalResult = TranscriptionResult(
            text: result.text,
            segments: result.segments,
            detectedLanguage: locale.identifier,
            averageConfidence: result.averageConfidence,
            speakingRate: result.speakingRate,
            metadata: buildMetadata(from: result, locale: locale, duration: duration),
            alternatives: result.alternatives,
            processingTime: processingTime
        )
        
        // Cache the result
        let cached = CachedTranscription(result: finalResult)
        transcriptionCache.setObject(cached, forKey: url as NSURL)
        
        logger.info("Transcription completed in \(processingTime) seconds")
        return finalResult
    }
    
    /// Start live transcription from microphone
    func startLiveTranscription(options: TranscriptionOptions = TranscriptionOptions()) async throws {
        logger.info("Starting live transcription")
        
        // Check authorization
        let authStatus = await requestAuthorization()
        guard authStatus == .authorized else {
            throw TranscriptionError.notAuthorized
        }
        
        // Request microphone permission
        let microphoneAuth = await AVCaptureDevice.requestAccess(for: .audio)
        guard microphoneAuth else {
            throw TranscriptionError.processingFailed("Microphone access denied")
        }
        
        // Determine language
        let locale = try await determineLanguage(for: nil, preference: options.language)
        
        // Get recognizer
        guard let recognizer = getRecognizer(for: locale),
              recognizer.isAvailable else {
            throw TranscriptionError.recognizerNotAvailable
        }
        
        isTranscribing = true
        
        try await startAudioEngine(with: recognizer, options: options)
    }
    
    /// Stop live transcription
    func stopLiveTranscription() {
        logger.info("Stopping live transcription")
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        currentTask?.cancel()
        currentTask = nil
        isTranscribing = false
        currentSegment = ""
        
        // Note: AVAudioSession is not needed on macOS
    }
    
    /// Generate natural language description of audio
    func generateAudioDescription(from result: TranscriptionResult) -> String {
        var description = ""
        
        // Basic info
        if let duration = result.metadata["duration"] as? TimeInterval {
            description += String(format: "This is a %.1f second audio recording. ", duration)
        }
        
        // Language info
        if let lang = result.detectedLanguage {
            let locale = Locale(identifier: lang)
            let languageName = locale.localizedString(forIdentifier: lang) ?? lang
            description += "The language spoken is \(languageName). "
        }
        
        // Speaking rate
        if result.speakingRate > 0 {
            let rateDescription = describeSpeakingRate(result.speakingRate)
            description += "The speaker is talking at a \(rateDescription) pace (\(Int(result.speakingRate)) words per minute). "
        }
        
        // Confidence
        let confidencePercent = Int(result.averageConfidence * 100)
        description += "Transcription confidence: \(confidencePercent)%. "
        
        // Content preview
        if !result.text.isEmpty {
            description += "\n\nTranscript: \"\(result.text)\""
        } else {
            description += "\n\nNo clear speech was detected in this audio."
        }
        
        // Add emotional tone analysis if available
        if let emotionalTone = analyzeEmotionalTone(from: result) {
            description += "\n\nEmotional tone: \(emotionalTone)"
        }
        
        return description
    }
    
    /// Check if speech recognition is available
    func isAvailable() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    /// Request speech recognition authorization
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func getRecognizer(for locale: Locale) -> SFSpeechRecognizer? {
        if let recognizer = recognizers[locale.identifier] {
            return recognizer
        }
        
        let recognizer = SFSpeechRecognizer(locale: locale)
        recognizers[locale.identifier] = recognizer
        return recognizer
    }
    
    private func configureRequest(_ request: SFSpeechRecognitionRequest, with options: TranscriptionOptions) {
        request.shouldReportPartialResults = options.shouldReportPartialResults
        request.taskHint = options.taskHint
        
        // Enable on-device recognition for better performance and privacy
        if #available(macOS 13.0, *) {
            request.requiresOnDeviceRecognition = true
        }
        
        // Add contextual strings for better accuracy
        request.contextualStrings = [
            "Gemi", "diary", "journal", "reflection", "memory",
            "feeling", "emotion", "today", "yesterday", "tomorrow"
        ]
        
        // Configure for dictation
        if options.taskHint == .dictation {
            request.addsPunctuation = options.includePunctuation
        }
    }
    
    private struct IntermediateResult {
        let text: String
        let segments: [TranscriptionSegment]
        let averageConfidence: Float
        let speakingRate: Double
        let alternatives: [[TranscriptionSegment]]
    }
    
    private func performTranscription(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechURLRecognitionRequest,
        duration: TimeInterval,
        options: TranscriptionOptions
    ) async throws -> IntermediateResult {
        
        return try await withCheckedThrowingContinuation { continuation in
            var alternatives: [[TranscriptionSegment]] = []
            var lastUpdateTime: TimeInterval = 0
            
            currentTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }
                
                if let error = error {
                    continuation.resume(throwing: TranscriptionError.processingFailed(error.localizedDescription))
                    return
                }
                
                if let result = result {
                    Task { @MainActor in
                        // Update progress
                        if let lastSegment = result.bestTranscription.segments.last {
                            let progress = min(lastSegment.timestamp / duration, 1.0)
                            self.transcriptionProgress = progress
                            
                            // Update current segment for live feedback
                            if lastSegment.timestamp > lastUpdateTime {
                                self.currentSegment = lastSegment.substring
                                lastUpdateTime = lastSegment.timestamp
                            }
                        }
                        
                        if result.isFinal {
                            // Process final results
                            let segments = self.processSegments(from: result.bestTranscription)
                            
                            // Process alternatives if requested
                            if options.includeAlternatives {
                                alternatives = self.processAlternatives(
                                    from: result.transcriptions,
                                    maxCount: options.maxAlternatives
                                )
                            }
                            
                            // Calculate metrics
                            let avgConfidence = segments.isEmpty ? 0 : 
                                segments.map { $0.confidence }.reduce(0, +) / Float(segments.count)
                            
                            let speakingRate = self.calculateSpeakingRate(
                                wordCount: result.bestTranscription.formattedString.split(separator: " ").count,
                                duration: duration
                            )
                            
                            let intermediateResult = IntermediateResult(
                                text: result.bestTranscription.formattedString,
                                segments: segments,
                                averageConfidence: avgConfidence,
                                speakingRate: speakingRate,
                                alternatives: alternatives
                            )
                            
                            continuation.resume(returning: intermediateResult)
                        }
                    }
                }
            }
        }
    }
    
    private func processSegments(from transcription: SFTranscription) -> [TranscriptionSegment] {
        return transcription.segments.map { segment in
            TranscriptionSegment(
                text: segment.substring,
                timestamp: segment.timestamp,
                duration: segment.duration,
                confidence: segment.confidence,
                alternativeInterpretations: segment.alternativeSubstrings
            )
        }
    }
    
    private func processAlternatives(
        from transcriptions: [SFTranscription],
        maxCount: Int
    ) -> [[TranscriptionSegment]] {
        return transcriptions.prefix(maxCount).map { transcription in
            processSegments(from: transcription)
        }
    }
    
    private func calculateSpeakingRate(wordCount: Int, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 0 }
        return Double(wordCount) / (duration / 60.0) // words per minute
    }
    
    private func getAudioDuration(url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
    
    private func determineLanguage(
        for audioURL: URL?,
        preference: TranscriptionOptions.Language
    ) async throws -> Locale {
        switch preference {
        case .specific(let locale):
            return locale
            
        case .automatic:
            // If we have an audio file, try to detect language
            if let url = audioURL {
                if let detectedLocale = await detectLanguageFromAudio(url: url) {
                    return detectedLocale
                }
            }
            
            // Default to system language or English
            let systemLanguage: String?
            if #available(macOS 13, *) {
                systemLanguage = Locale.current.language.languageCode?.identifier
            } else {
                systemLanguage = Locale.current.languageCode
            }
            
            if let systemLang = systemLanguage,
               let matchingLocale = self.availableLanguages.first(where: { locale in
                   if #available(macOS 13, *) {
                       return locale.language.languageCode?.identifier == systemLang
                   } else {
                       return locale.languageCode == systemLang
                   }
               }) {
                return matchingLocale
            }
            
            return Locale(identifier: "en-US")
        }
    }
    
    private func detectLanguageFromAudio(url: URL) async -> Locale? {
        logger.info("Attempting automatic language detection")
        
        // Try transcribing with top 3 languages and pick best confidence
        let testLanguages = ["en-US", "es-ES", "zh-CN"].compactMap { identifier in
            availableLanguages.first { $0.identifier == identifier }
        }
        
        var bestResult: (locale: Locale, confidence: Float)?
        
        for locale in testLanguages {
            if let recognizer = getRecognizer(for: locale),
               recognizer.isAvailable {
                
                // Create a short test request (first 10 seconds)
                let request = SFSpeechURLRecognitionRequest(url: url)
                request.shouldReportPartialResults = false
                
                if #available(macOS 13.0, *) {
                    request.requiresOnDeviceRecognition = true
                }
                
                // Quick recognition test
                let testResult = await performQuickRecognition(
                    with: recognizer,
                    request: request
                )
                
                if let result = testResult,
                   bestResult == nil || result.confidence > bestResult!.confidence {
                    bestResult = (locale: locale, confidence: result.confidence)
                }
            }
        }
        
        return bestResult?.locale
    }
    
    private func performQuickRecognition(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechURLRecognitionRequest
    ) async -> (text: String, confidence: Float)? {
        
        await withCheckedContinuation { continuation in
            let task = recognizer.recognitionTask(with: request) { result, error in
                if let result = result, result.isFinal {
                    let segments = result.bestTranscription.segments
                    let avgConfidence = segments.isEmpty ? 0 :
                        segments.map { $0.confidence }.reduce(0, +) / Float(segments.count)
                    
                    continuation.resume(returning: (
                        text: result.bestTranscription.formattedString,
                        confidence: avgConfidence
                    ))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            // Timeout after 5 seconds
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                task.cancel()
            }
        }
    }
    
    private func startAudioEngine(
        with recognizer: SFSpeechRecognizer,
        options: TranscriptionOptions
    ) async throws {
        // Note: AVAudioSession is not needed on macOS
        // macOS handles audio permissions differently
        
        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        configureRequest(request, with: options)
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        // Prepare and start engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition
        currentTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let result = result {
                    self.currentSegment = result.bestTranscription.segments.last?.substring ?? ""
                    
                    if result.isFinal {
                        self.stopLiveTranscription()
                    }
                }
                
                if let error = error {
                    self.logger.error("Live transcription error: \(error)")
                    self.lastError = error
                    self.stopLiveTranscription()
                }
            }
        }
    }
    
    private func buildMetadata(
        from result: IntermediateResult,
        locale: Locale,
        duration: TimeInterval
    ) -> [String: Any] {
        var metadata: [String: Any] = [
            "duration": duration,
            "wordCount": result.text.split(separator: " ").count,
            "language": locale.identifier,
            "languageName": locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier,
            "segmentCount": result.segments.count,
            "speakingRate": result.speakingRate
        ]
        
        // Add pause analysis
        let pauses = analyzePauses(in: result.segments)
        metadata["pauseCount"] = pauses.count
        metadata["averagePauseDuration"] = pauses.isEmpty ? 0 : 
            pauses.map { $0.duration }.reduce(0, +) / Double(pauses.count)
        
        // Add voice characteristics (placeholder for future enhancement)
        metadata["voiceCharacteristics"] = [
            "clarity": result.averageConfidence,
            "consistency": calculateConsistency(from: result.segments)
        ]
        
        return metadata
    }
    
    private struct Pause {
        let timestamp: TimeInterval
        let duration: TimeInterval
    }
    
    private func analyzePauses(in segments: [TranscriptionSegment]) -> [Pause] {
        var pauses: [Pause] = []
        
        for i in 1..<segments.count {
            let previousEnd = segments[i-1].timestamp + segments[i-1].duration
            let currentStart = segments[i].timestamp
            let pauseDuration = currentStart - previousEnd
            
            if pauseDuration > 0.5 { // Consider pauses longer than 0.5 seconds
                pauses.append(Pause(timestamp: previousEnd, duration: pauseDuration))
            }
        }
        
        return pauses
    }
    
    private func calculateConsistency(from segments: [TranscriptionSegment]) -> Float {
        guard segments.count > 1 else { return 1.0 }
        
        let confidences = segments.map { $0.confidence }
        let mean = confidences.reduce(0, +) / Float(confidences.count)
        
        let variance = confidences.map { pow($0 - mean, 2) }.reduce(0, +) / Float(confidences.count)
        let standardDeviation = sqrt(variance)
        
        // Return inverse of coefficient of variation (lower variation = higher consistency)
        return mean > 0 ? 1.0 - min(standardDeviation / mean, 1.0) : 0
    }
    
    private func describeSpeakingRate(_ rate: Double) -> String {
        if rate < 100 { return "very slow" }
        if rate < 130 { return "slow" }
        if rate < 160 { return "normal" }
        if rate < 200 { return "fast" }
        return "very fast"
    }
    
    private func analyzeEmotionalTone(from result: TranscriptionResult) -> String? {
        // Simple heuristic analysis based on speech patterns
        // In a real implementation, this could use more sophisticated audio analysis
        
        let text = result.text.lowercased()
        let speakingRate = result.speakingRate
        let pauseCount = result.metadata["pauseCount"] as? Int ?? 0
        let avgPauseDuration = result.metadata["averagePauseDuration"] as? Double ?? 0
        
        // Check for emotional indicators in text
        let excitedWords = ["amazing", "wonderful", "fantastic", "incredible", "excited"]
        let sadWords = ["sad", "sorry", "difficult", "hard", "tough", "unfortunately"]
        let angryWords = ["angry", "frustrated", "annoyed", "irritated", "mad"]
        let happyWords = ["happy", "joy", "glad", "pleased", "delighted", "great"]
        
        var emotionalIndicators: [String] = []
        
        // Text-based emotion detection
        if excitedWords.contains(where: { text.contains($0) }) {
            emotionalIndicators.append("excited")
        }
        if sadWords.contains(where: { text.contains($0) }) {
            emotionalIndicators.append("sad")
        }
        if angryWords.contains(where: { text.contains($0) }) {
            emotionalIndicators.append("frustrated")
        }
        if happyWords.contains(where: { text.contains($0) }) {
            emotionalIndicators.append("happy")
        }
        
        // Speech pattern analysis
        if speakingRate > 180 {
            emotionalIndicators.append("energetic or anxious")
        } else if speakingRate < 120 {
            emotionalIndicators.append("calm or tired")
        }
        
        if pauseCount > 10 && avgPauseDuration > 1.5 {
            emotionalIndicators.append("thoughtful or hesitant")
        }
        
        // Exclamation analysis
        let exclamationCount = text.filter { $0 == "!" }.count
        if exclamationCount > 2 {
            emotionalIndicators.append("emphatic")
        }
        
        // Question analysis
        let questionCount = text.filter { $0 == "?" }.count
        if questionCount > 3 {
            emotionalIndicators.append("uncertain or inquisitive")
        }
        
        if emotionalIndicators.isEmpty {
            return nil
        }
        
        return "The speaker sounds " + emotionalIndicators.joined(separator: " and ")
    }
}