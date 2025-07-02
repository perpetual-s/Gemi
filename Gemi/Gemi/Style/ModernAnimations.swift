//
//  ModernAnimations.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

// MARK: - Animation Modifiers

/// Adds a gentle floating animation
struct FloatingAnimation: ViewModifier {
    @State private var offsetY: CGFloat = 0
    let amplitude: CGFloat
    let duration: Double
    
    init(amplitude: CGFloat = 10, duration: Double = 3) {
        self.amplitude = amplitude
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .offset(y: offsetY)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    offsetY = amplitude
                }
            }
    }
}

/// Adds a pulsing scale animation
struct PulseAnimation: ViewModifier {
    @State private var scale: CGFloat = 1.0
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double
    
    init(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05, duration: Double = 2) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = maxScale
                }
            }
    }
}

/// Adds a shimmer effect
struct ShimmerAnimation: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    
    init(duration: Double = 2) {
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase * 400 - 200)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

/// Adds a gentle shake animation
struct ShakeAnimation: ViewModifier {
    let trigger: Bool
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { oldValue, newValue in
                withAnimation(
                    .easeInOut(duration: 0.1)
                    .repeatCount(3, autoreverses: true)
                ) {
                    offset = 5
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    offset = 0
                }
            }
    }
}

/// Adds a bounce-in animation
struct BounceInAnimation: ViewModifier {
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    let delay: Double
    
    init(delay: Double = 0) {
        self.delay = delay
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    ModernDesignSystem.Animation.bounce
                    .delay(delay)
                ) {
                    scale = 1
                    opacity = 1
                }
            }
    }
}

/// Adds a slide and fade animation
struct SlideAndFadeAnimation: ViewModifier {
    @State private var offset: CGFloat = 20
    @State private var opacity: Double = 0
    let delay: Double
    let direction: Edge
    
    init(from direction: Edge = .bottom, delay: Double = 0) {
        self.delay = delay
        self.direction = direction
        
        switch direction {
        case .top:
            _offset = State(initialValue: -20)
        case .bottom:
            _offset = State(initialValue: 20)
        case .leading:
            _offset = State(initialValue: -20)
        case .trailing:
            _offset = State(initialValue: 20)
        }
    }
    
    func body(content: Content) -> some View {
        content
            .offset(
                x: direction == .leading || direction == .trailing ? offset : 0,
                y: direction == .top || direction == .bottom ? offset : 0
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    ModernDesignSystem.Animation.spring
                    .delay(delay)
                ) {
                    offset = 0
                    opacity = 1
                }
            }
    }
}

// MARK: - Transition Extensions

extension AnyTransition {
    /// Modern scale and opacity transition
    static var modernScale: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
    
    /// Card flip transition
    static var cardFlip: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.1, anchor: .leading).combined(with: .opacity),
            removal: .scale(scale: 0.1, anchor: .trailing).combined(with: .opacity)
        )
    }
    
    /// Slide with spring
    static func slideWithSpring(edge: Edge) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .move(edge: edge.opposite).combined(with: .opacity)
        )
    }
}

// Helper for opposite edge
extension Edge {
    var opposite: Edge {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
}

// MARK: - Interactive Components

/// Ripple effect on tap
struct RippleEffect: ViewModifier {
    @State private var ripples: [Ripple] = []
    
    struct Ripple: Identifiable {
        let id = UUID()
        let position: CGPoint
        let startTime = Date()
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    ZStack {
                        ForEach(ripples) { ripple in
                            RippleView(
                                position: ripple.position,
                                maxRadius: max(geometry.size.width, geometry.size.height)
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
            )
            .onTapGesture { location in
                ripples.append(Ripple(position: location))
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    ripples.removeFirst()
                }
            }
    }
    
    struct RippleView: View {
        let position: CGPoint
        let maxRadius: CGFloat
        @State private var radius: CGFloat = 0
        @State private var opacity: Double = 0.3
        
        var body: some View {
            Circle()
                .fill(ModernDesignSystem.Colors.primary)
                .frame(width: radius * 2, height: radius * 2)
                .position(position)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8)) {
                        radius = maxRadius
                        opacity = 0
                    }
                }
        }
    }
}

/// Parallax scrolling effect
struct ParallaxEffect: ViewModifier {
    let multiplier: CGFloat
    @State private var scrollOffset: CGFloat = 0
    
    init(multiplier: CGFloat = 0.5) {
        self.multiplier = multiplier
    }
    
    func body(content: Content) -> some View {
        content
            .offset(y: scrollOffset * multiplier)
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Loading Animations

/// Modern typing indicator animation
struct ModernTypingIndicator: View {
    @State private var animationStates = [false, false, false]
    let dotSize: CGFloat = 8
    let spacing: CGFloat = 4
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(ModernDesignSystem.Colors.textSecondary)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(animationStates[index] ? 1.3 : 1.0)
                    .opacity(animationStates[index] ? 1.0 : 0.5)
            }
        }
        .onAppear {
            animateDots()
        }
    }
    
    private func animateDots() {
        for index in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.2)
            ) {
                animationStates[index] = true
            }
        }
    }
}

/// Success checkmark animation
struct SuccessCheckmark: View {
    @State private var trimEnd: CGFloat = 0
    @State private var scale: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(ModernDesignSystem.Colors.success.opacity(0.1))
                .frame(width: 80, height: 80)
                .scaleEffect(scale)
            
            Path { path in
                path.move(to: CGPoint(x: 25, y: 40))
                path.addLine(to: CGPoint(x: 35, y: 50))
                path.addLine(to: CGPoint(x: 55, y: 30))
            }
            .trim(from: 0, to: trimEnd)
            .stroke(
                ModernDesignSystem.Colors.success,
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 80, height: 80)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 1
            }
            
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                trimEnd = 1
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    // Animation modifiers
    func floatingAnimation(amplitude: CGFloat = 10, duration: Double = 3) -> some View {
        modifier(FloatingAnimation(amplitude: amplitude, duration: duration))
    }
    
    func pulseAnimation(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05, duration: Double = 2) -> some View {
        modifier(PulseAnimation(minScale: minScale, maxScale: maxScale, duration: duration))
    }
    
    func shimmerAnimation(duration: Double = 2) -> some View {
        modifier(ShimmerAnimation(duration: duration))
    }
    
    func shakeAnimation(trigger: Bool) -> some View {
        modifier(ShakeAnimation(trigger: trigger))
    }
    
    func bounceIn(delay: Double = 0) -> some View {
        modifier(BounceInAnimation(delay: delay))
    }
    
    func slideAndFade(from edge: Edge = .bottom, delay: Double = 0) -> some View {
        modifier(SlideAndFadeAnimation(from: edge, delay: delay))
    }
    
    func rippleEffect() -> some View {
        modifier(RippleEffect())
    }
    
    func parallax(multiplier: CGFloat = 0.5) -> some View {
        modifier(ParallaxEffect(multiplier: multiplier))
    }
}

// MARK: - Animated Background

/// Animated gradient background
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    let colors: [Color]
    
    init(colors: [Color] = [
        ModernDesignSystem.Colors.primary.opacity(0.1),
        ModernDesignSystem.Colors.moodReflective.opacity(0.1),
        ModernDesignSystem.Colors.moodCalm.opacity(0.1)
    ]) {
        self.colors = colors
    }
    
    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .linear(duration: 5)
                .repeatForever(autoreverses: true)
            ) {
                animateGradient.toggle()
            }
        }
    }
}

/// Particle effect background
struct ParticleBackground: View {
    @State private var particles: [Particle] = []
    let particleCount = 50
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let size: CGFloat
        let opacity: Double
        let speed: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(ModernDesignSystem.Colors.primary)
                        .frame(width: particle.size, height: particle.size)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                        .animation(
                            .linear(duration: particle.speed)
                            .repeatForever(autoreverses: false),
                            value: particle.y
                        )
                }
            }
            .onAppear {
                generateParticles(in: geometry.size)
                animateParticles(in: geometry.size)
            }
        }
    }
    
    private func generateParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.1...0.3),
                speed: Double.random(in: 20...40)
            )
        }
    }
    
    private func animateParticles(in size: CGSize) {
        for index in particles.indices {
            particles[index].y = -particles[index].size
        }
    }
}