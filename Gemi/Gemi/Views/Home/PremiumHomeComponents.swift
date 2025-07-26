import SwiftUI

// MARK: - Magnetic Action Card

struct MagneticActionCard: View {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let mouseLocation: CGPoint
    let cardCenter: CGPoint
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var rotation3D = Double.zero
    @State private var magneticOffset = CGSize.zero
    @State private var glowAnimation = false
    
    private var distance: CGFloat {
        let dx = mouseLocation.x - cardCenter.x
        let dy = mouseLocation.y - cardCenter.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private var magneticEffect: CGSize {
        guard distance < 200 else { return .zero }
        
        let strength = 1 - (distance / 200)
        let dx = (mouseLocation.x - cardCenter.x) * strength * 0.1
        let dy = (mouseLocation.y - cardCenter.y) * strength * 0.1
        
        return CGSize(width: dx, height: dy)
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Glow effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.opacity(0.3))
                    .blur(radius: 20)
                    .scaleEffect(glowAnimation ? 1.1 : 0.9)
                    .opacity(isHovered ? 0.8 : 0)
                
                // Card background
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(NSColor.controlBackgroundColor),
                                Color(NSColor.controlBackgroundColor).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isHovered ? 0.2 : 0.1),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: color.opacity(isHovered ? 0.3 : 0.1),
                        radius: isHovered ? 20 : 10,
                        y: isHovered ? 10 : 5
                    )
                
                // Content
                VStack(spacing: 12) {
                    // Icon with animation
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.2), color.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .rotationEffect(.degrees(isHovered ? 10 : 0))
                            .scaleEffect(isPressed ? 0.9 : 1.0)
                    }
                    
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.primary)
                        
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.secondary)
                    }
                }
                .padding(24)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .offset(magneticOffset)
        .rotation3DEffect(
            .degrees(rotation3D),
            axis: (x: -magneticOffset.height / 20, y: magneticOffset.width / 20, z: 0)
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
                glowAnimation = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3)) {
                        isPressed = false
                    }
                }
        )
        .onChange(of: mouseLocation) { _, _ in
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8)) {
                magneticOffset = magneticEffect
                rotation3D = Double(distance < 200 ? (200 - distance) / 10 : 0)
            }
        }
    }
}

// MARK: - Time Based Icon

struct TimeBasedIcon: View {
    let hour: Int
    @State private var iconRotation = 0.0
    @State private var particleOffset = CGSize.zero
    
    private var iconName: String {
        switch hour {
        case 5..<12: return "sun.max.fill"
        case 12..<17: return "sun.min.fill"
        case 17..<21: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }
    
    private var iconColor: Color {
        switch hour {
        case 5..<12: return Color(red: 1.0, green: 0.8, blue: 0.2)   // Warm golden yellow for morning sun
        case 12..<17: return Color(red: 1.0, green: 0.9, blue: 0.0)  // Bright yellow for afternoon
        case 17..<21: return .orange                                  // Orange for sunset/evening
        default: return .indigo                                       // Deep indigo for night
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            iconColor.opacity(0.2),
                            iconColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
            
            // Animated particles around icon
            ForEach(0..<6) { index in
                Circle()
                    .fill(iconColor.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .offset(
                        x: cos(iconRotation + Double(index) * .pi / 3) * 40,
                        y: sin(iconRotation + Double(index) * .pi / 3) * 40
                    )
            }
            
            // Main icon
            Image(systemName: iconName)
                .font(.system(size: 56, weight: .medium, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [iconColor, iconColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: iconColor.opacity(0.5), radius: 10, y: 2)
                .rotationEffect(.degrees(iconRotation * 10))
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                iconRotation = .pi * 2
            }
        }
    }
}

// MARK: - Premium Stat Card

struct PremiumStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    @State private var isVisible = false
    @State private var numberAnimation = 0.0
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, value: isVisible)
                
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primary, Color.primary.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .contentTransition(.numericText())
            }
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.8)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Particle System

@MainActor
class HomeParticleSystem: ObservableObject {
    @Published var particles: [HomeParticle] = []
    var attractorPosition: CGPoint?
    private var timer: Timer?
    
    func startEmitting() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                self.updateParticles()
                if self.particles.count < 50 {
                    self.particles.append(HomeParticle())
                }
            }
        }
    }
    
    func updateParticles() {
        particles = particles.compactMap { particle in
            var p = particle
            p.update(attractor: attractorPosition)
            return p.lifetime > 0 ? p : nil
        }
    }
    
    func stopEmitting() {
        timer?.invalidate()
        timer = nil
    }
}

struct HomeParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var lifetime: Double
    let color: Color
    let size: CGFloat
    
    init() {
        position = CGPoint(
            x: CGFloat.random(in: 0...1200),
            y: CGFloat.random(in: 0...800)
        )
        velocity = CGVector(
            dx: CGFloat.random(in: -20...20),
            dy: CGFloat.random(in: -20...20)
        )
        lifetime = Double.random(in: 3...6)
        color = [Color.purple, Color.blue, Color.orange].randomElement()!.opacity(0.6)
        size = CGFloat.random(in: 2...6)
    }
    
    mutating func update(attractor: CGPoint?) {
        // Apply attraction force if near cursor
        if let attractor = attractor {
            let dx = attractor.x - position.x
            let dy = attractor.y - position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < 200 && distance > 10 {
                let force = 50 / distance
                velocity.dx += dx / distance * force * 0.01
                velocity.dy += dy / distance * force * 0.01
            }
        }
        
        // Apply velocity with damping
        position.x += velocity.dx * 0.02
        position.y += velocity.dy * 0.02
        velocity.dx *= 0.98
        velocity.dy *= 0.98
        
        // Update lifetime
        lifetime -= 0.016
    }
}

struct ParticleFieldView: View {
    let mouseLocation: CGPoint
    @ObservedObject var particleSystem: HomeParticleSystem
    
    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                for particle in particleSystem.particles {
                    let opacity = min(1.0, particle.lifetime / 2.0)
                    
                    context.fill(
                        Circle().path(in: CGRect(
                            x: particle.position.x - particle.size / 2,
                            y: particle.position.y - particle.size / 2,
                            width: particle.size,
                            height: particle.size
                        )),
                        with: .color(particle.color.opacity(opacity))
                    )
                }
            }
        }
    }
}