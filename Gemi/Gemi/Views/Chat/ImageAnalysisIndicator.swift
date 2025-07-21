import SwiftUI

/// Visual indicator shown when Gemi is analyzing an image
struct ImageAnalysisIndicator: View {
    @State private var isAnimating = false
    @State private var pulseAmount: CGFloat = 1.0
    let imageData: Data?
    let isAnalyzing: Bool
    
    var body: some View {
        if let imageData = imageData, let nsImage = NSImage(data: imageData) {
            ZStack {
                // Image preview
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 150)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    )
                    .scaleEffect(isAnalyzing ? pulseAmount : 1.0)
                
                if isAnalyzing {
                    // Analysis overlay
                    ZStack {
                        // Scanning effect
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.3),
                                        Color.purple.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(isAnimating ? 1.1 : 0.9)
                            .opacity(isAnimating ? 0 : 0.6)
                        
                        // Analysis indicator
                        VStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                                .tint(.white)
                            
                            Text("Analyzing image...")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.7))
                                )
                        }
                    }
                }
            }
            .onAppear {
                if isAnalyzing {
                    startAnimations()
                }
            }
            .onChange(of: isAnalyzing) { oldValue, newValue in
                if newValue {
                    startAnimations()
                } else {
                    stopAnimations()
                }
            }
        }
    }
    
    private func startAnimations() {
        // Pulse animation
        withAnimation(
            .easeInOut(duration: 1.0)
            .repeatForever(autoreverses: true)
        ) {
            pulseAmount = 1.05
        }
        
        // Scan animation
        withAnimation(
            .easeOut(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            isAnimating = true
        }
    }
    
    private func stopAnimations() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulseAmount = 1.0
            isAnimating = false
        }
    }
}

/// Enhanced attachment preview with analysis feedback
struct EnhancedAttachmentPreview: View {
    let attachment: AttachmentManager.Attachment
    @State private var isAnalyzing = false
    @State private var analysisResult: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image with analysis indicator
            ImageAnalysisIndicator(
                imageData: attachment.data,
                isAnalyzing: isAnalyzing
            )
            
            // Analysis result
            if let result = analysisResult {
                Text(result)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            simulateAnalysis()
        }
    }
    
    private func simulateAnalysis() {
        isAnalyzing = true
        
        // Simulate analysis time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring()) {
                isAnalyzing = false
                
                // Generate contextual result based on attachment
                if let imageData = attachment.data,
                   let analysis = MultimodalSimulator.analyzeImage(imageData) {
                    analysisResult = "Detected: \(analysis.description) • Mood: \(analysis.mood)"
                }
            }
        }
    }
}

/// Message bubble enhancement for multimodal content
extension StreamingMessageBubble {
    @ViewBuilder
    func multimodalContent() -> some View {
        if let images = message.images, !images.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Image attachments
                ForEach(images.indices, id: \.self) { index in
                    if let imageData = Data(base64Encoded: images[index]
                        .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                        .replacingOccurrences(of: "data:image/png;base64,", with: "")) {
                        
                        let attachment = AttachmentManager.Attachment(
                            id: UUID(),
                            type: .image,
                            data: imageData,
                            url: nil
                        )
                        
                        EnhancedAttachmentPreview(attachment: attachment)
                    }
                }
                
                // Message text
                messageContent()
            }
        } else {
            messageContent()
        }
    }
}

// MARK: - Preview
struct ImageAnalysisIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Analyzing state
            ImageAnalysisIndicator(
                imageData: createSampleImage(),
                isAnalyzing: true
            )
            
            // Completed state
            ImageAnalysisIndicator(
                imageData: createSampleImage(),
                isAnalyzing: false
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
    
    static func createSampleImage() -> Data? {
        let size = CGSize(width: 300, height: 200)
        guard let image = NSImage(size: size) else { return nil }
        
        image.lockFocus()
        NSColor.systemBlue.withAlphaComponent(0.3).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        
        return image.tiffRepresentation
    }
}