//
//  MilestoneCelebration.swift
//  Gemi
//
//  Celebration system for writing milestones
//

import SwiftUI

// MARK: - Milestone Definition

enum WritingMilestone: Int, CaseIterable {
    case spark = 50
    case ignite = 100
    case flame = 250
    case blaze = 500
    case inferno = 750
    case supernova = 1000
    
    var title: String {
        switch self {
        case .spark: return "First Spark!"
        case .ignite: return "Getting Started!"
        case .flame: return "On Fire!"
        case .blaze: return "Blazing Trail!"
        case .inferno: return "Daily Goal!"
        case .supernova: return "You're Unstoppable!"
        }
    }
    
    var emoji: String {
        switch self {
        case .spark: return "✨"
        case .ignite: return "🔥"
        case .flame: return "🔥"
        case .blaze: return "🚀"
        case .inferno: return "🎯"
        case .supernova: return "⭐"
        }
    }
    
    var color: Color {
        switch self {
        case .spark: return .yellow
        case .ignite: return .orange
        case .flame: return .orange
        case .blaze: return .red
        case .inferno: return .purple
        case .supernova: return .indigo
        }
    }
    
    var celebrationStyle: CelebrationStyle {
        switch self {
        case .spark: return .subtle
        case .ignite: return .gentle
        case .flame: return .balanced
        case .blaze: return .energetic
        case .inferno: return .epic
        case .supernova: return .legendary
        }
    }
}

enum CelebrationStyle {
    case subtle      // 3-5 particles
    case gentle      // 8-10 particles
    case balanced    // 15-20 particles
    case energetic   // 25-30 particles
    case epic        // 40-50 particles
    case legendary   // 60+ particles with special effects
}

// MARK: - Celebration View

struct MilestoneCelebrationView: View {
    @Binding var currentWordCount: Int
    @State private var celebratedMilestones: Set<WritingMilestone> = []
    @State private var activeParticles: [CelebrationParticle] = []
    @State private var showingBanner = false
    @State private var currentMilestone: WritingMilestone?
    
    // Settings
    @AppStorage("celebrationsEnabled") private var isEnabled = true
    @AppStorage("celebrationIntensity") private var intensity: Double = 1.0
    
    private let particleTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            if isEnabled {
                // Particles
                ForEach(activeParticles) { particle in
                    ParticleView(particle: particle)
                }
                
                // Milestone banner
                if showingBanner, let milestone = currentMilestone {
                    MilestoneBanner(milestone: milestone)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                        .zIndex(1000)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: currentWordCount) { oldValue, newValue in
            checkForMilestone(oldCount: oldValue, newCount: newValue)
        }
        .onReceive(particleTimer) { _ in
            updateParticles()
        }
    }
    
    // MARK: - Milestone Detection
    
    private func checkForMilestone(oldCount: Int, newCount: Int) {
        guard isEnabled else { return }
        
        for milestone in WritingMilestone.allCases {
            if oldCount < milestone.rawValue && newCount >= milestone.rawValue {
                if !celebratedMilestones.contains(milestone) {
                    celebrate(milestone)
                    celebratedMilestones.insert(milestone)
                }
            }
        }
    }
    
    // MARK: - Celebration Logic
    
    private func celebrate(_ milestone: WritingMilestone) {
        currentMilestone = milestone
        
        // Show banner
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showingBanner = true
        }
        
        // Create particles based on style
        createParticles(for: milestone)
        
        // Hide banner after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.5)) {
                showingBanner = false
            }
        }
        
        // Optional: Haptic feedback on macOS 12.0+
        if #available(macOS 12.0, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        }
    }
    
    private func createParticles(for milestone: WritingMilestone) {
        let count: Int
        let style = milestone.celebrationStyle
        
        switch style {
        case .subtle:
            count = Int(5 * intensity)
        case .gentle:
            count = Int(10 * intensity)
        case .balanced:
            count = Int(20 * intensity)
        case .energetic:
            count = Int(30 * intensity)
        case .epic:
            count = Int(50 * intensity)
        case .legendary:
            count = Int(80 * intensity)
        }
        
        // Create particles with varying properties
        for i in 0..<count {
            let delay = Double(i) * 0.02 // Stagger creation
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let particle = CelebrationParticle(
                    milestone: milestone,
                    style: style,
                    intensity: intensity
                )
                activeParticles.append(particle)
            }
        }
    }
    
    private func updateParticles() {
        // Remove expired particles
        activeParticles.removeAll { particle in
            particle.isExpired
        }
        
        // Update positions
        for i in activeParticles.indices {
            activeParticles[i].update()
        }
    }
}

// MARK: - Celebration Particle

struct CelebrationParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var color: Color
    var size: CGFloat
    var rotation: Double
    var opacity: Double
    let lifetime: Double
    let createdAt: Date
    let shape: ParticleShape
    
    enum ParticleShape: CaseIterable {
        case circle, star, square, triangle
    }
    
    init(milestone: WritingMilestone, style: CelebrationStyle, intensity: Double) {
        // Random starting position (center of screen with variance)
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        
        position = CGPoint(
            x: screenWidth / 2 + CGFloat.random(in: -50...50),
            y: screenHeight / 2 + CGFloat.random(in: -50...50)
        )
        
        // Velocity based on style
        let speed: CGFloat = switch style {
        case .subtle: CGFloat.random(in: 50...100)
        case .gentle: CGFloat.random(in: 100...150)
        case .balanced: CGFloat.random(in: 150...250)
        case .energetic: CGFloat.random(in: 200...350)
        case .epic: CGFloat.random(in: 300...500)
        case .legendary: CGFloat.random(in: 400...600)
        }
        
        let angle = CGFloat.random(in: 0...(2 * .pi))
        velocity = CGVector(
            dx: cos(angle) * speed * intensity,
            dy: sin(angle) * speed * intensity
        )
        
        // Visual properties
        color = milestone.color
        size = CGFloat.random(in: 8...20) * intensity
        rotation = Double.random(in: 0...360)
        opacity = 1.0
        lifetime = Double.random(in: 1.5...3.0)
        createdAt = Date()
        shape = ParticleShape.allCases.randomElement()!
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > lifetime
    }
    
    mutating func update() {
        // Update position
        position.x += velocity.dx * 0.016 // 60 FPS
        position.y += velocity.dy * 0.016
        
        // Apply gravity
        velocity.dy += 100 * 0.016 // Gravity acceleration
        
        // Apply drag
        velocity.dx *= 0.99
        velocity.dy *= 0.99
        
        // Update rotation
        rotation += 5
        
        // Fade out
        let age = Date().timeIntervalSince(createdAt)
        opacity = max(0, 1.0 - (age / lifetime))
    }
}

// MARK: - Particle View

struct ParticleView: View {
    let particle: CelebrationParticle
    
    var body: some View {
        Group {
            switch particle.shape {
            case .circle:
                Circle()
                    .fill(particle.color)
            case .star:
                Image(systemName: "star.fill")
                    .font(.system(size: particle.size))
                    .foregroundColor(particle.color)
            case .square:
                RoundedRectangle(cornerRadius: particle.size * 0.2)
                    .fill(particle.color)
            case .triangle:
                TriangleShape()
                    .fill(particle.color)
            }
        }
        .frame(width: particle.size, height: particle.size)
        .rotationEffect(.degrees(particle.rotation))
        .opacity(particle.opacity)
        .position(particle.position)
        .blur(radius: particle.opacity < 0.5 ? 2 : 0)
    }
}

// MARK: - Milestone Banner

struct MilestoneBanner: View {
    let milestone: WritingMilestone
    @State private var isVisible = false
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Text(milestone.emoji)
                    .font(.system(size: 40))
                    .rotationEffect(.degrees(isVisible ? 0 : -180))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(milestone.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(milestone.rawValue) words!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Text(milestone.emoji)
                    .font(.system(size: 40))
                    .rotationEffect(.degrees(isVisible ? 0 : 180))
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                milestone.color,
                                milestone.color.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: milestone.color.opacity(0.5), radius: 20, y: 10)
            )
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
            
            Spacer()
        }
        .padding(.top, 100)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Triangle Shape

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}