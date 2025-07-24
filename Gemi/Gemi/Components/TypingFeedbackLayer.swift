//
//  TypingFeedbackLayer.swift
//  Gemi
//
//  Visual feedback system for typing with ripples and flow states
//

import SwiftUI
import Combine

// MARK: - Typing Ripple Model

struct TypeRipple: Identifiable {
    let id = UUID()
    let position: CGPoint
    let character: Character
    let timestamp: Date
    
    var opacity: Double {
        let elapsed = Date().timeIntervalSince(timestamp)
        return max(0, 1.0 - (elapsed / 0.3)) // 300ms fade
    }
    
    var scale: CGFloat {
        let elapsed = Date().timeIntervalSince(timestamp)
        return 1.0 + CGFloat(elapsed * 2) // Expand over time
    }
}

// MARK: - Typing Feedback Layer

struct TypingFeedbackLayer: View {
    @Binding var isTyping: Bool
    @Binding var typingSpeed: Double // Words per minute
    @Binding var lastKeyPosition: CGPoint?
    
    @State private var ripples: [TypeRipple] = []
    @State private var flowIntensity: Double = 0
    @State private var breathingScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    
    // Settings
    @AppStorage("typingFeedbackEnabled") private var isEnabled = true
    @AppStorage("typingFeedbackIntensity") private var intensity = 0.5
    
    private let rippleTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect() // 60 FPS
    
    var body: some View {
        ZStack {
            if isEnabled {
                // Background flow state glow
                if flowIntensity > 0 {
                    flowStateBackground
                }
                
                // Ripple effects
                ForEach(ripples) { ripple in
                    RippleView(ripple: ripple, intensity: intensity)
                }
                
                // Cursor enhancement (if we have position)
                if let position = lastKeyPosition {
                    cursorEnhancement(at: position)
                }
            }
        }
        .allowsHitTesting(false) // Don't interfere with typing
        .onReceive(rippleTimer) { _ in
            updateRipples()
            updateFlowState()
        }
        .onChange(of: isTyping) { _, newValue in
            if newValue {
                startBreathingAnimation()
            } else {
                stopBreathingAnimation()
            }
        }
    }
    
    // MARK: - Flow State Background
    
    private var flowStateBackground: some View {
        GeometryReader { geometry in
            // Edge particles
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Theme.Colors.primaryAccent.opacity(0.1 * flowIntensity),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .position(
                        x: index == 0 ? -100 : (index == 1 ? geometry.size.width + 100 : geometry.size.width / 2),
                        y: index == 2 ? -100 : geometry.size.height / 2
                    )
                    .blur(radius: 50)
                    .animation(.easeInOut(duration: 3), value: flowIntensity)
            }
            
            // Ambient tint
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.Colors.primaryAccent.opacity(0.02 * flowIntensity),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Cursor Enhancement
    
    private func cursorEnhancement(at position: CGPoint) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Theme.Colors.primaryAccent.opacity(glowOpacity * intensity),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 30
                )
            )
            .frame(width: 60, height: 60)
            .scaleEffect(breathingScale)
            .position(position)
            .blur(radius: 10)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: breathingScale)
    }
    
    // MARK: - Public Methods
    
    func addRipple(at position: CGPoint, character: Character) {
        guard isEnabled else { return }
        
        let ripple = TypeRipple(
            position: position,
            character: character,
            timestamp: Date()
        )
        
        ripples.append(ripple)
        
        // Limit ripples for performance
        if ripples.count > 10 {
            ripples.removeFirst()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateRipples() {
        // Remove faded ripples
        ripples.removeAll { ripple in
            ripple.opacity <= 0.01
        }
    }
    
    private func updateFlowState() {
        // Calculate flow intensity based on typing speed
        let targetIntensity: Double
        
        if !isTyping {
            targetIntensity = 0
        } else if typingSpeed > 60 {
            targetIntensity = 1.0 // Full flow state
        } else if typingSpeed > 40 {
            targetIntensity = 0.7
        } else if typingSpeed > 20 {
            targetIntensity = 0.4
        } else {
            targetIntensity = 0.2
        }
        
        // Smooth transition
        withAnimation(.easeInOut(duration: 1.0)) {
            flowIntensity = targetIntensity
        }
    }
    
    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            breathingScale = 1.2
            glowOpacity = 0.5
        }
    }
    
    private func stopBreathingAnimation() {
        withAnimation(.easeOut(duration: 0.5)) {
            breathingScale = 1.0
            glowOpacity = 0.3
        }
    }
}

// MARK: - Ripple View

struct RippleView: View {
    let ripple: TypeRipple
    let intensity: Double
    
    var body: some View {
        Circle()
            .stroke(
                Theme.Colors.primaryAccent.opacity(ripple.opacity * 0.3 * intensity),
                lineWidth: 2
            )
            .frame(width: 20, height: 20)
            .scaleEffect(ripple.scale)
            .position(ripple.position)
            .animation(.easeOut(duration: 0.3), value: ripple.scale)
    }
}

// MARK: - Typing Metrics Tracker

@MainActor
class TypingMetrics: ObservableObject {
    @Published var isTyping = false
    @Published var currentWPM: Double = 0
    @Published var lastKeyPosition: CGPoint?
    
    private var lastTypeTime: Date?
    private var wordBuffer: String = ""
    private var wpmSamples: [Double] = []
    private var typingTimer: Timer?
    
    func recordKeystroke(character: Character, position: CGPoint? = nil) {
        let now = Date()
        
        // Update position
        lastKeyPosition = position
        
        // Mark as typing
        isTyping = true
        resetTypingTimer()
        
        // Add to word buffer
        if character.isWhitespace {
            if !wordBuffer.isEmpty {
                recordWord()
                wordBuffer = ""
            }
        } else if character.isLetter {
            wordBuffer.append(character)
        }
        
        lastTypeTime = now
    }
    
    private func recordWord() {
        guard let lastTime = lastTypeTime else { return }
        
        let timeDiff = Date().timeIntervalSince(lastTime)
        if timeDiff > 0 && timeDiff < 5 { // Reasonable typing speed
            let wpm = 60.0 / timeDiff
            wpmSamples.append(wpm)
            
            // Keep last 10 samples
            if wpmSamples.count > 10 {
                wpmSamples.removeFirst()
            }
            
            // Calculate average
            currentWPM = wpmSamples.reduce(0, +) / Double(wpmSamples.count)
        }
    }
    
    private func resetTypingTimer() {
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            Task { @MainActor in
                self.isTyping = false
                self.currentWPM = 0
                self.wpmSamples.removeAll()
            }
        }
    }
}