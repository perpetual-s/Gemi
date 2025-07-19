import SwiftUI

/// A celebratory view shown when onboarding and setup are complete
struct OnboardingCompletionView: View {
    let userName: String?
    let onContinue: () -> Void
    
    @State private var showContent = false
    @State private var showCheckmark = false
    @State private var showTitle = false
    @State private var showMessage = false
    @State private var showButton = false
    @State private var particleSystem = ParticleSystem()
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
            
            // Particles
            ParticleEmitterView(particleSystem: particleSystem)
                .allowsHitTesting(false)
                .opacity(showContent ? 1 : 0)
                .animation(.easeInOut(duration: 1.5), value: showContent)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Success checkmark with animation
                ZStack {
                    // Pulsing circle background
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.green.opacity(0.3),
                                    Color.green.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                        .opacity(pulseAnimation ? 0.8 : 0.3)
                        .animation(
                            .easeInOut(duration: 2)
                            .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                    
                    // Checkmark circle
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: .green.opacity(0.5), radius: 20, y: 10)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(showCheckmark ? 1 : 0.3)
                    .opacity(showCheckmark ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showCheckmark)
                }
                
                VStack(spacing: 16) {
                    // Title
                    Text("Welcome to Gemi!")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.3), value: showTitle)
                    
                    // Personalized message
                    Text(welcomeMessage)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                        .opacity(showMessage ? 1 : 0)
                        .offset(y: showMessage ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.5), value: showMessage)
                }
                
                Spacer()
                
                // Continue button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onContinue()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("Start Writing")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                    }
                    .foregroundStyle(.black)
                    .frame(minWidth: 200)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(.white)
                            .shadow(color: .white.opacity(0.3), radius: 20, y: 10)
                    )
                }
                .scaleEffect(showButton ? 1 : 0.8)
                .opacity(showButton ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8), value: showButton)
                
                Spacer()
            }
            .padding(40)
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    private var welcomeMessage: String {
        if let name = userName, !name.isEmpty {
            return "Your private AI diary is ready, \(name). Every thought, every moment, stays safely on your device."
        } else {
            return "Your private AI diary is ready. Every thought, every moment, stays safely on your device."
        }
    }
    
    private func startAnimationSequence() {
        // Start particle emission
        particleSystem.birthRate = 0.5
        
        // Animate in sequence
        withAnimation {
            showContent = true
            pulseAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showCheckmark = true
            
            // Burst of particles on checkmark appearance
            particleSystem.birthRate = 3
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                particleSystem.birthRate = 0.5
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showTitle = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showMessage = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showButton = true
        }
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var animate = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.3),
                Color(red: 0.2, green: 0.1, blue: 0.4),
                Color(red: 0.1, green: 0.2, blue: 0.3)
            ],
            startPoint: animate ? .topLeading : .bottomTrailing,
            endPoint: animate ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

// MARK: - Particle System

@MainActor
class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    @Published var birthRate: Double = 0
    
    private var timer: Timer?
    
    init() {
        startEmitting()
    }
    
    func startEmitting() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.updateParticles()
                
                // Add new particles based on birth rate
                let particlesToAdd = Int(self.birthRate * 0.1 * 10) // particles per 0.1 second
                for _ in 0..<particlesToAdd {
                    self.particles.append(Particle())
                }
            }
        }
    }
    
    func updateParticles() {
        // Update existing particles
        particles = particles.compactMap { particle in
            var p = particle
            p.update()
            return p.lifetime > 0 ? p : nil
        }
    }
    
    func stopEmitting() {
        timer?.invalidate()
        timer = nil
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var lifetime: Double
    var scale: Double
    var opacity: Double
    let color: Color
    
    init() {
        // Random starting position at bottom of screen
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        let screenHeight = NSScreen.main?.frame.height ?? 800
        position = CGPoint(
            x: CGFloat.random(in: -50...(screenWidth + 50)),
            y: screenHeight + 50
        )
        
        // Upward velocity with some randomness
        velocity = CGVector(
            dx: CGFloat.random(in: -30...30),
            dy: CGFloat.random(in: -150...(-80))
        )
        
        lifetime = Double.random(in: 3...5)
        scale = Double.random(in: 0.3...1.0)
        opacity = 1.0
        
        // Random pastel colors
        color = [
            Color.purple.opacity(0.8),
            Color.blue.opacity(0.8),
            Color.green.opacity(0.8),
            Color.orange.opacity(0.8),
            Color.pink.opacity(0.8)
        ].randomElement()!
    }
    
    mutating func update() {
        position.x += velocity.dx * 0.016 // 60fps
        position.y += velocity.dy * 0.016
        lifetime -= 0.016
        opacity = min(1.0, lifetime / 2.0) // Fade out in last 2 seconds
    }
}

struct ParticleEmitterView: View {
    @ObservedObject var particleSystem: ParticleSystem
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particleSystem.particles {
                    let rect = CGRect(
                        x: particle.position.x - 4 * particle.scale,
                        y: particle.position.y - 4 * particle.scale,
                        width: 8 * particle.scale,
                        height: 8 * particle.scale
                    )
                    
                    context.opacity = particle.opacity
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(particle.color)
                    )
                }
            }
        }
    }
}

// MARK: - Preview

struct OnboardingCompletionView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingCompletionView(
            userName: "Sarah",
            onContinue: {}
        )
    }
}