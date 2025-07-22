import SwiftUI

/// Test view for multimodal AI services
struct MultimodalTestView: View {
    @StateObject private var multimodalService = MultimodalAIService.shared
    @StateObject private var attachmentManager = AttachmentManager.shared
    @StateObject private var visionService = VisionAnalysisService.shared
    @StateObject private var speechService = SpeechTranscriptionService.shared
    
    @State private var testImage: NSImage?
    @State private var testAudioURL: URL?
    @State private var isProcessing = false
    @State private var results = ""
    @State private var error: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Multimodal AI Test")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                // Image Test
                VStack {
                    Text("Vision Test")
                        .font(.headline)
                    
                    if let image = testImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .border(Color.gray, width: 1)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(
                                Text("Drop Image Here")
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    HStack {
                        Button("Load Test Image") {
                            loadTestImage()
                        }
                        
                        Button("Test Vision") {
                            Task {
                                await testVisionAnalysis()
                            }
                        }
                        .disabled(testImage == nil || isProcessing)
                    }
                }
                
                // Audio Test
                VStack {
                    Text("Speech Test")
                        .font(.headline)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(
                            VStack {
                                Image(systemName: "waveform")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                
                                if testAudioURL != nil {
                                    Text("Audio Loaded")
                                        .foregroundColor(.green)
                                }
                            }
                        )
                    
                    HStack {
                        Button("Record Audio") {
                            Task {
                                await recordTestAudio()
                            }
                        }
                        
                        Button("Test Speech") {
                            Task {
                                await testSpeechTranscription()
                            }
                        }
                        .disabled(testAudioURL == nil || isProcessing)
                    }
                }
            }
            
            // Multimodal Test
            Button("Test Full Multimodal Flow") {
                Task {
                    await testMultimodalFlow()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
            
            // Progress
            if isProcessing {
                ProgressView()
                    .progressViewStyle(.linear)
                
                if !multimodalService.currentOperation.isEmpty {
                    Text(multimodalService.currentOperation)
                        .foregroundColor(.secondary)
                }
            }
            
            // Results
            ScrollView {
                Text(results.isEmpty ? "Results will appear here..." : results)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Error
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .frame(width: 800, height: 700)
    }
    
    // MARK: - Test Functions
    
    private func loadTestImage() {
        // Create a test image with text
        let size = NSSize(width: 400, height: 300)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw some text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        
        let text = "Hello from Gemi!\nThis is a test image\nwith multiple lines"
        text.draw(at: NSPoint(x: 50, y: 150), withAttributes: attributes)
        
        // Draw a shape
        NSColor.blue.setFill()
        NSBezierPath(ovalIn: NSRect(x: 250, y: 100, width: 100, height: 100)).fill()
        
        image.unlockFocus()
        
        testImage = image
        results = "Test image loaded with text and shapes"
    }
    
    private func recordTestAudio() async {
        // For testing, create a dummy audio file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_audio_\(UUID().uuidString).m4a")
        
        // In a real test, we would actually record audio
        // For now, just pretend we have an audio file
        testAudioURL = tempURL
        results = "Audio recording simulated (would record real audio in production)"
    }
    
    private func testVisionAnalysis() async {
        guard let image = testImage else { return }
        
        isProcessing = true
        error = nil
        results = "Testing Vision Analysis...\n\n"
        
        do {
            let analysisResult = try await visionService.analyzeImage(image)
            
            results += "=== Vision Analysis Results ===\n"
            results += "Processing Time: \(String(format: "%.2f", analysisResult.processingTime))s\n\n"
            
            results += "Extracted Text:\n\"\(analysisResult.extractedText)\"\n\n"
            
            results += "Classifications:\n"
            for classification in analysisResult.classifications.prefix(5) {
                results += "- \(classification.identifier): \(String(format: "%.1f%%", classification.confidence * 100))\n"
            }
            results += "\n"
            
            results += "Detected Objects: \(analysisResult.detectedObjects.count)\n"
            results += "Face Count: \(analysisResult.faceCount)\n"
            results += "Dominant Colors: \(analysisResult.dominantColors.count)\n\n"
            
            let description = visionService.generateImageDescription(from: analysisResult)
            results += "Natural Language Description:\n\(description)"
            
        } catch {
            self.error = "Vision analysis failed: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    private func testSpeechTranscription() async {
        guard let audioURL = testAudioURL else { return }
        
        isProcessing = true
        error = nil
        results = "Testing Speech Transcription...\n\n"
        
        // For demo purposes, simulate transcription
        results += "=== Speech Transcription Results ===\n"
        results += "Audio URL: \(audioURL.lastPathComponent)\n"
        results += "Status: Would transcribe audio file here\n"
        results += "Expected output: Transcribed text with timestamps and confidence scores"
        
        isProcessing = false
    }
    
    private func testMultimodalFlow() async {
        isProcessing = true
        error = nil
        results = "Testing Full Multimodal Flow...\n\n"
        
        // Add test attachments
        if let image = testImage {
            do {
                try await attachmentManager.addImage(image, fileName: "test_image.png")
                results += "✓ Added test image to attachments\n"
            } catch {
                self.error = "Failed to add image: \(error.localizedDescription)"
            }
        }
        
        // Create multimodal context
        do {
            let context = try await multimodalService.createMultimodalContext(for: "What do you see in this image?")
            
            results += "\n=== Multimodal Context Created ===\n"
            results += "Original Message: \(context.originalMessage)\n\n"
            results += "Enhanced Prompt:\n\(context.enhancedPrompt)\n\n"
            results += "Processing Time: \(String(format: "%.2f", context.totalProcessingTime))s\n\n"
            
            for (index, attachment) in context.processedAttachments.enumerated() {
                results += "Attachment \(index + 1):\n"
                results += "Type: \(attachment.originalType)\n"
                results += "Description: \(attachment.textDescription)\n"
                results += "Processing Time: \(String(format: "%.2f", attachment.processingTime))s\n\n"
            }
            
        } catch {
            self.error = "Multimodal processing failed: \(error.localizedDescription)"
        }
        
        // Clear attachments
        attachmentManager.clearAttachments()
        
        isProcessing = false
    }
}

#Preview {
    MultimodalTestView()
}