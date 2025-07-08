import SwiftUI

/// Real-time sentiment indicator that analyzes the emotional tone of writing
struct SentimentIndicator: View {
    let sentiment: SentimentAnalysis
    @State private var animatedValue: Double = 0
    @State private var pulseAnimation = false
    
    struct SentimentAnalysis {
        let score: Double // -1.0 (very negative) to 1.0 (very positive)
        let confidence: Double // 0.0 to 1.0
        let dominantEmotion: Emotion
        let emotions: [Emotion: Double]
        
        enum Emotion: String, CaseIterable {
            case joy = "Joy"
            case sadness = "Sadness"
            case anger = "Anger"
            case fear = "Fear"
            case surprise = "Surprise"
            case love = "Love"
            case neutral = "Neutral"
            
            var color: Color {
                switch self {
                case .joy: return .yellow
                case .sadness: return .blue
                case .anger: return .red
                case .fear: return .purple
                case .surprise: return .orange
                case .love: return .pink
                case .neutral: return .gray
                }
            }
            
            var icon: String {
                switch self {
                case .joy: return "sun.max.fill"
                case .sadness: return "cloud.rain.fill"
                case .anger: return "flame.fill"
                case .fear: return "exclamationmark.triangle.fill"
                case .surprise: return "exclamationmark.2"
                case .love: return "heart.fill"
                case .neutral: return "minus.circle.fill"
                }
            }
        }
        
        static let neutral = SentimentAnalysis(
            score: 0,
            confidence: 0,
            dominantEmotion: .neutral,
            emotions: [.neutral: 1.0]
        )
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Compact bar view
            sentimentBar
            
            // Emotion breakdown (shown on hover)
            if sentiment.confidence > 0.3 {
                emotionBreakdown
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: sentiment.score)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animatedValue = sentiment.score
            }
        }
        .onChange(of: sentiment.score) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedValue = newValue
                pulseAnimation.toggle()
            }
        }
    }
    
    private var sentimentBar: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: sentiment.dominantEmotion.icon)
                .font(.system(size: 14))
                .foregroundColor(sentiment.dominantEmotion.color)
                .symbolEffect(.pulse, value: pulseAnimation)
            
            // Gradient bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 8)
                    
                    // Gradient fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width, height: 8)
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle()
                                    .frame(width: geometry.size.width * normalizedPosition)
                                Spacer(minLength: 0)
                            }
                        )
                    
                    // Position indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: indicatorColor.opacity(0.3), radius: 4)
                        .overlay(
                            Circle()
                                .stroke(indicatorColor, lineWidth: 2)
                        )
                        .position(
                            x: geometry.size.width * normalizedPosition,
                            y: geometry.size.height / 2
                        )
                }
            }
            .frame(height: 16)
            
            // Confidence indicator
            if sentiment.confidence > 0 {
                Text("\(Int(sentiment.confidence * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .opacity(sentiment.confidence)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        )
    }
    
    private var emotionBreakdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Emotional Tone")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            // Top emotions
            let sortedEmotions = sentiment.emotions
                .sorted { $0.value > $1.value }
                .filter { $0.value > 0.1 }
                .prefix(3)
            
            ForEach(sortedEmotions, id: \.key) { emotion, value in
                HStack(spacing: 8) {
                    Image(systemName: emotion.icon)
                        .font(.system(size: 12))
                        .foregroundColor(emotion.color)
                        .frame(width: 16)
                    
                    Text(emotion.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Mini progress bar
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(emotion.color.opacity(0.2))
                            .overlay(
                                HStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(emotion.color)
                                        .frame(width: geometry.size.width * value)
                                    Spacer(minLength: 0)
                                }
                            )
                    }
                    .frame(width: 40, height: 4)
                    
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Computed Properties
    
    private var normalizedPosition: Double {
        // Convert -1 to 1 range to 0 to 1 range
        return (animatedValue + 1) / 2
    }
    
    private var gradientColors: [Color] {
        [
            Color.red,
            Color.orange,
            Color.yellow,
            Color.green,
            Color.blue
        ]
    }
    
    private var indicatorColor: Color {
        if animatedValue < -0.6 {
            return .red
        } else if animatedValue < -0.2 {
            return .orange
        } else if animatedValue < 0.2 {
            return .yellow
        } else if animatedValue < 0.6 {
            return .green
        } else {
            return .blue
        }
    }
}

// MARK: - Sentiment Analyzer Service

@MainActor
class SentimentAnalyzer: ObservableObject {
    @Published var currentAnalysis = SentimentIndicator.SentimentAnalysis.neutral
    private var analysisTimer: Timer?
    private let debounceInterval: TimeInterval = 1.0
    
    func analyzeText(_ text: String) {
        // Cancel previous timer
        analysisTimer?.invalidate()
        
        // Debounce analysis to avoid too frequent updates
        analysisTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { _ in
            Task { @MainActor in
                self.performAnalysis(text)
            }
        }
    }
    
    private func performAnalysis(_ text: String) {
        // This is a simplified mock implementation
        // In production, this would call the AI service
        
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        // Simple keyword-based analysis (mock)
        var emotionScores: [SentimentIndicator.SentimentAnalysis.Emotion: Double] = [:]
        
        // Joy keywords
        let joyWords = ["happy", "joy", "excited", "wonderful", "amazing", "great", "fantastic", "love"]
        let joyCount = words.filter { joyWords.contains($0) }.count
        
        // Sadness keywords
        let sadWords = ["sad", "depressed", "lonely", "miss", "cry", "tears", "grief", "loss"]
        let sadCount = words.filter { sadWords.contains($0) }.count
        
        // Calculate simple scores
        let totalEmotionalWords = Double(joyCount + sadCount)
        let confidence = min(totalEmotionalWords / Double(max(words.count, 1)) * 5, 1.0)
        
        if totalEmotionalWords > 0 {
            emotionScores[.joy] = Double(joyCount) / totalEmotionalWords
            emotionScores[.sadness] = Double(sadCount) / totalEmotionalWords
        } else {
            emotionScores[.neutral] = 1.0
        }
        
        // Calculate overall sentiment score
        let score = (Double(joyCount) - Double(sadCount)) / max(totalEmotionalWords, 1.0)
        
        // Determine dominant emotion
        let dominantEmotion = emotionScores.max(by: { $0.value < $1.value })?.key ?? .neutral
        
        withAnimation {
            currentAnalysis = SentimentIndicator.SentimentAnalysis(
                score: score,
                confidence: confidence,
                dominantEmotion: dominantEmotion,
                emotions: emotionScores
            )
        }
    }
}

// MARK: - Preview Helper

struct SentimentIndicatorPreview: View {
    @State private var sentiment = SentimentIndicator.SentimentAnalysis(
        score: 0.6,
        confidence: 0.8,
        dominantEmotion: .joy,
        emotions: [
            .joy: 0.7,
            .love: 0.2,
            .neutral: 0.1
        ]
    )
    
    var body: some View {
        VStack(spacing: 20) {
            SentimentIndicator(sentiment: sentiment)
                .frame(width: 300)
            
            Button("Random Sentiment") {
                sentiment = SentimentIndicator.SentimentAnalysis(
                    score: Double.random(in: -1...1),
                    confidence: Double.random(in: 0.3...1),
                    dominantEmotion: SentimentIndicator.SentimentAnalysis.Emotion.allCases.randomElement()!,
                    emotions: [
                        .joy: Double.random(in: 0...1),
                        .sadness: Double.random(in: 0...1),
                        .love: Double.random(in: 0...1)
                    ]
                )
            }
        }
        .padding()
    }
}