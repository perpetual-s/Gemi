import SwiftUI

struct SparkleAnimationView: View {
    // Core animation states
    @State private var animationPhase = 0.0
    @State private var breathingScale = 1.0
    @State private var glowIntensity = 0.5
    @State private var morphOffset = CGSize.zero
    @State private var particlesRevealed = false
    @State private var emojiRotation = 0.0
    @State private var chromaticOffset = 0.0
    
    // Multi-layer glow states
    @State private var innerGlow = 0.8
    @State private var outerGlow = 0.3
    @State private var pulsePhase = 0.0
    
    // Enhanced particle system
    private let innerParticles = 8
    private let outerParticles = 12
    private let microParticles = 20
    
    var body: some View {
        ZStack {
            // Multi-layered background effects
            backgroundLayers
            
            // Micro particle field for depth
            ForEach(0..<microParticles, id: \.self) { index in
                MicroSparkle(
                    index: index,
                    totalCount: microParticles,
                    revealed: particlesRevealed,
                    phase: animationPhase
                )
            }
            
            // Inner ring of larger sparkles
            ForEach(0..<innerParticles, id: \.self) { index in
                EnhancedSparkleParticle(
                    index: index,
                    totalCount: innerParticles,
                    radius: 80,
                    size: .large,
                    revealed: particlesRevealed,
                    animationPhase: animationPhase,
                    delayMultiplier: 0.08
                )
            }
            
            // Outer ring of smaller sparkles
            ForEach(0..<outerParticles, id: \.self) { index in
                EnhancedSparkleParticle(
                    index: index,
                    totalCount: outerParticles,
                    radius: 120,
                    size: .medium,
                    revealed: particlesRevealed,
                    animationPhase: animationPhase,
                    delayMultiplier: 0.05
                )
            }
            
            // Central emoji with sophisticated effects
            centralEmoji
        }
        .frame(width: 300, height: 300)
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Background Layers
    
    @ViewBuilder
    private var backgroundLayers: some View {
        // Morphing gradient base
        ZStack {
            // Primary glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(innerGlow),
                            Color.blue.opacity(outerGlow),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 150
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(morphOffset)
            
            // Secondary pulsing glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.pink.opacity(pulsePhase),
                            Color.purple.opacity(pulsePhase * 0.5),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 120
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 30)
                .scaleEffect(1 + pulsePhase * 0.2)
            
            // Chromatic aberration layers
            Circle()
                .fill(Color.red.opacity(0.1))
                .frame(width: 150, height: 150)
                .blur(radius: 20)
                .offset(x: -chromaticOffset, y: 0)
            
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 150, height: 150)
                .blur(radius: 20)
                .offset(x: chromaticOffset, y: 0)
        }
    }
    
    // MARK: - Central Emoji
    
    @ViewBuilder
    private var centralEmoji: some View {
        Text("✨")
            .font(.system(size: 100))
            .scaleEffect(breathingScale)
            .rotationEffect(.degrees(emojiRotation))
            .shadow(color: Color.purple.opacity(0.6), radius: 20)
            .shadow(color: Color.blue.opacity(0.4), radius: 30)
            .shadow(color: Color.white.opacity(0.3), radius: 5)
            .overlay(
                // Subtle inner glow
                Text("✨")
                    .font(.system(size: 100))
                    .foregroundColor(.white)
                    .blur(radius: 8)
                    .opacity(glowIntensity)
                    .blendMode(.plusLighter)
                    .scaleEffect(breathingScale)
                    .rotationEffect(.degrees(emojiRotation))
            )
    }
    
    // MARK: - Animation Orchestration
    
    private func startAnimations() {
        // Cascade reveal animation
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            particlesRevealed = true
        }
        
        // Sophisticated breathing animation
        withAnimation(
            Animation.easeInOut(duration: 3.5)
                .repeatForever(autoreverses: true)
        ) {
            breathingScale = 1.08
            glowIntensity = 0.8
        }
        
        // Gentle rotation with variable speed
        withAnimation(
            Animation.easeInOut(duration: 8)
                .repeatForever(autoreverses: true)
        ) {
            emojiRotation = 10
        }
        
        // Morphing background
        withAnimation(
            Animation.easeInOut(duration: 5)
                .repeatForever(autoreverses: true)
        ) {
            morphOffset = CGSize(width: 20, height: 20)
            innerGlow = 1.0
            outerGlow = 0.5
        }
        
        // Pulse animation
        withAnimation(
            Animation.easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
        ) {
            pulsePhase = 0.6
        }
        
        // Chromatic effect
        withAnimation(
            Animation.linear(duration: 4)
                .repeatForever(autoreverses: true)
        ) {
            chromaticOffset = 3
        }
        
        // Particle orbit animation
        withAnimation(
            Animation.linear(duration: 20)
                .repeatForever(autoreverses: false)
        ) {
            animationPhase = 360
        }
    }
}

// MARK: - Enhanced Sparkle Particle

struct EnhancedSparkleParticle: View {
    enum Size {
        case small, medium, large
        
        var scale: CGFloat {
            switch self {
            case .small: return 0.6
            case .medium: return 0.8
            case .large: return 1.0
            }
        }
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 18
            case .large: return 24
            }
        }
    }
    
    let index: Int
    let totalCount: Int
    let radius: CGFloat
    let size: Size
    let revealed: Bool
    let animationPhase: Double
    let delayMultiplier: Double
    
    @State private var sparkleScale = 0.0
    @State private var sparkleOpacity = 0.0
    @State private var sparkleRotation = 0.0
    @State private var shimmer = false
    
    private var baseAngle: Double {
        (Double(index) / Double(totalCount)) * 360
    }
    
    private var xPosition: CGFloat {
        150 + cos((baseAngle + animationPhase) * .pi / 180) * radius
    }
    
    private var yPosition: CGFloat {
        150 + sin((baseAngle + animationPhase) * .pi / 180) * radius
    }
    
    private var delay: Double {
        Double(index) * delayMultiplier
    }
    
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size.fontSize))
            .foregroundStyle(
                LinearGradient(
                    colors: shimmer ? 
                        [Color.white, Color.purple.opacity(0.8)] :
                        [Color.purple.opacity(0.8), Color.blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(sparkleScale * size.scale)
            .opacity(sparkleOpacity)
            .rotationEffect(.degrees(sparkleRotation))
            .position(x: xPosition, y: yPosition)
            .shadow(color: Color.purple.opacity(0.5), radius: 4)
            .shadow(color: Color.white.opacity(0.3), radius: 2)
            .onChange(of: revealed) { _, newValue in
                if newValue {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay)) {
                        sparkleScale = 1.0
                        sparkleOpacity = 1.0
                    }
                    
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(delay)) {
                        shimmer = true
                    }
                    
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false).delay(delay)) {
                        sparkleRotation = index % 2 == 0 ? 360 : -360
                    }
                }
            }
    }
}

// MARK: - Micro Sparkle

struct MicroSparkle: View {
    let index: Int
    let totalCount: Int
    let revealed: Bool
    let phase: Double
    
    @State private var opacity = 0.0
    @State private var scale = 0.0
    
    private var randomRadius: CGFloat {
        CGFloat.random(in: 40...140)
    }
    
    private var randomAngle: Double {
        (Double(index) / Double(totalCount)) * 360 + Double.random(in: -30...30)
    }
    
    private var xPosition: CGFloat {
        150 + cos((randomAngle + phase * 0.5) * .pi / 180) * randomRadius
    }
    
    private var yPosition: CGFloat {
        150 + sin((randomAngle + phase * 0.5) * .pi / 180) * randomRadius
    }
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white, Color.white.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 2
                )
            )
            .frame(width: 4, height: 4)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(x: xPosition, y: yPosition)
            .onChange(of: revealed) { _, newValue in
                if newValue {
                    let delay = Double(index) * 0.03
                    withAnimation(.easeOut(duration: 1.0).delay(delay)) {
                        opacity = 0.6
                        scale = 1.0
                    }
                    
                    withAnimation(
                        .easeInOut(duration: Double.random(in: 2...4))
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                    ) {
                        opacity = 0.2
                    }
                }
            }
    }
}