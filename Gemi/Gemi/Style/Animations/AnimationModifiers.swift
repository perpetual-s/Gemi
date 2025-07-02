//
//  AnimationModifiers.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

// MARK: - Entrance Animations

struct FadeInModifier: ViewModifier {
    @State private var isVisible = false
    let delay: Double
    let duration: Double
    
    init(delay: Double = 0, duration: Double = 0.3) {
        self.delay = delay
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

struct ScaleInModifier: ViewModifier {
    @State private var isVisible = false
    let delay: Double
    let from: Double
    
    init(delay: Double = 0, from: Double = 0.9) {
        self.delay = delay
        self.from = from
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : from)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(DesignSystem.Animation.encouragingSpring.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

struct SlideInModifier: ViewModifier {
    enum Direction {
        case leading, trailing, top, bottom
    }
    
    @State private var isVisible = false
    let direction: Direction
    let delay: Double
    let distance: CGFloat
    
    init(from direction: Direction, delay: Double = 0, distance: CGFloat = 20) {
        self.direction = direction
        self.delay = delay
        self.distance = distance
    }
    
    private var offset: CGSize {
        guard !isVisible else { return .zero }
        
        switch direction {
        case .leading:
            return CGSize(width: -distance, height: 0)
        case .trailing:
            return CGSize(width: distance, height: 0)
        case .top:
            return CGSize(width: 0, height: -distance)
        case .bottom:
            return CGSize(width: 0, height: distance)
        }
    }
    
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(DesignSystem.Animation.standard.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Interactive Feedback

struct PressableModifier: ViewModifier {
    @State private var isPressed = false
    let scale: Double
    
    init(scale: Double = 0.95) {
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1)
            .animation(DesignSystem.Animation.quick, value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    let scale: Double
    let shadowRadius: CGFloat
    
    init(scale: Double = 1.02, shadowRadius: CGFloat = 8) {
        self.scale = scale
        self.shadowRadius = shadowRadius
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1)
            .shadow(
                color: DesignSystem.Colors.shadowMedium.opacity(isHovered ? 0.15 : 0.08),
                radius: isHovered ? shadowRadius : 4,
                y: isHovered ? 4 : 2
            )
            .animation(DesignSystem.Animation.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Ambient Animations

struct FloatingModifier: ViewModifier {
    @State private var offset: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?
    let amplitude: CGFloat
    let duration: Double
    
    init(amplitude: CGFloat = 10, duration: Double = 3) {
        self.amplitude = amplitude
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                animationTask = Task {
                    while !Task.isCancelled {
                        withAnimation(.easeInOut(duration: duration)) {
                            offset = amplitude
                        }
                        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                        
                        if Task.isCancelled { break }
                        
                        withAnimation(.easeInOut(duration: duration)) {
                            offset = 0
                        }
                        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                    }
                }
            }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
                offset = 0
            }
    }
}

struct PulseModifier: ViewModifier {
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 0.8
    @State private var animationTask: Task<Void, Never>?
    let targetScale: Double
    let targetOpacity: Double
    
    init(scale: Double = 1.05, opacity: Double = 0.8) {
        self.targetScale = scale
        self.targetOpacity = opacity
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                content
                    .scaleEffect(scale)
                    .opacity(opacity)
            )
            .onAppear {
                animationTask = Task {
                    while !Task.isCancelled {
                        withAnimation(DesignSystem.Animation.heartbeat) {
                            scale = targetScale
                            opacity = 0
                        }
                        try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000))
                        
                        if Task.isCancelled { break }
                        
                        scale = 1
                        opacity = targetOpacity
                    }
                }
            }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
                scale = 1
                opacity = targetOpacity
            }
    }
}

struct ParallaxModifier: GeometryEffect {
    let magnitude: CGFloat
    var offset: CGFloat
    
    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let transform = CGAffineTransform(translationX: 0, y: offset * magnitude)
        return ProjectionTransform(transform)
    }
}

// MARK: - Loading States

struct SkeletonModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @State private var animationTask: Task<Void, Never>?
    let gradient: LinearGradient
    
    init() {
        self.gradient = LinearGradient(
            colors: [
                DesignSystem.Colors.backgroundTertiary,
                DesignSystem.Colors.backgroundSecondary,
                DesignSystem.Colors.backgroundTertiary
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    gradient
                        .frame(width: geometry.size.width * 2)
                        .offset(x: phase * geometry.size.width)
                }
                .mask(content)
            )
            .onAppear {
                animationTask = Task {
                    while !Task.isCancelled {
                        withAnimation(.linear(duration: 1.5)) {
                            phase = 1
                        }
                        try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000))
                        
                        if Task.isCancelled { break }
                        
                        phase = -1
                    }
                }
            }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
                phase = -1
            }
    }
}

// MARK: - Transition Effects

struct FadeTransition: ViewModifier {
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .animation(DesignSystem.Animation.standard, value: isVisible)
    }
}

// MARK: - Reduced Motion Support

struct ReducedMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let reducedAnimation: Animation?
    
    init(animation: Animation?, reducedAnimation: Animation? = .linear(duration: 0.1)) {
        self.animation = animation
        self.reducedAnimation = reducedAnimation
    }
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? reducedAnimation : animation, value: UUID())
    }
}

// MARK: - View Extensions

extension View {
    func fadeIn(delay: Double = 0, duration: Double = 0.3) -> some View {
        modifier(FadeInModifier(delay: delay, duration: duration))
    }
    
    func scaleIn(delay: Double = 0, from: Double = 0.9) -> some View {
        modifier(ScaleInModifier(delay: delay, from: from))
    }
    
    func slideIn(from direction: SlideInModifier.Direction, delay: Double = 0, distance: CGFloat = 20) -> some View {
        modifier(SlideInModifier(from: direction, delay: delay, distance: distance))
    }
    
    func pressable(scale: Double = 0.95) -> some View {
        modifier(PressableModifier(scale: scale))
    }
    
    func hoverEffect(scale: Double = 1.02, shadowRadius: CGFloat = 8) -> some View {
        modifier(HoverEffectModifier(scale: scale, shadowRadius: shadowRadius))
    }
    
    func floating(amplitude: CGFloat = 10, duration: Double = 3) -> some View {
        modifier(FloatingModifier(amplitude: amplitude, duration: duration))
    }
    
    func pulse(scale: Double = 1.05, opacity: Double = 0.8) -> some View {
        modifier(PulseModifier(scale: scale, opacity: opacity))
    }
    
    func parallax(magnitude: CGFloat = 0.2, offset: CGFloat) -> some View {
        modifier(ParallaxModifier(magnitude: magnitude, offset: offset))
    }
    
    func skeleton() -> some View {
        modifier(SkeletonModifier())
    }
    
    func fadeTransition(isVisible: Bool) -> some View {
        modifier(FadeTransition(isVisible: isVisible))
    }
    
    func respectedAnimation(_ animation: Animation?, reducedAnimation: Animation? = .linear(duration: 0.1)) -> some View {
        modifier(ReducedMotionModifier(animation: animation, reducedAnimation: reducedAnimation))
    }
}

// MARK: - Haptic Feedback

struct HapticFeedback {
    static func impact(_ style: NSHapticFeedbackManager.FeedbackPattern = .generic) {
        NSHapticFeedbackManager.defaultPerformer.perform(style, performanceTime: .now)
    }
    
    static func selection() {
        impact(.generic)
    }
    
    static func success() {
        impact(.levelChange)
    }
    
    static func warning() {
        impact(.alignment)
    }
    
    static func error() {
        impact(.generic)
    }
}