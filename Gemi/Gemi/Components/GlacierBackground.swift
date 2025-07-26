//
//  GlacierBackground.swift
//  Gemi
//
//  Glacier-inspired continuous background animation
//

import SwiftUI

struct GlacierBackground: View {
    @State private var phase1: CGFloat = 0
    @State private var phase2: CGFloat = 0
    @State private var phase3: CGFloat = 0
    @State private var gradientRotation: Double = 0
    @State private var iceParticles: [IceParticle] = []
    
    let currentHour: Int
    
    init(currentHour: Int = Calendar.current.component(.hour, from: Date())) {
        self.currentHour = currentHour
    }
    
    var body: some View {
        ZStack {
            // Base gradient layer
            baseGradientLayer
            
            // Flowing glacier layers
            glacierLayer1
            glacierLayer2
            glacierLayer3
            
            // Subtle ice particle effect
            iceParticleLayer
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimations()
            generateIceParticles()
        }
    }
    
    // MARK: - Base Gradient
    
    private var baseGradientLayer: some View {
        LinearGradient(
            colors: baseColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .hueRotation(.degrees(gradientRotation))
        .animation(.linear(duration: 60).repeatForever(autoreverses: true), value: gradientRotation)
        .onAppear {
            gradientRotation = 10
        }
    }
    
    private var baseColors: [Color] {
        switch currentHour {
        case 5..<12:  // Morning - Sky blue
            return [
                Color(red: 0.85, green: 0.95, blue: 1.0),
                Color(red: 0.75, green: 0.9, blue: 1.0),
                Color(red: 0.65, green: 0.85, blue: 1.0).opacity(0.8)
            ]
        case 12..<17:  // Afternoon - Bright day colors
            return [
                Color(red: 1.0, green: 0.98, blue: 0.85),
                Color(red: 0.98, green: 0.95, blue: 0.75),
                Color(red: 0.95, green: 0.92, blue: 0.65).opacity(0.8)
            ]
        case 17..<21:  // Evening - Sunset orange
            return [
                Color(red: 1.0, green: 0.8, blue: 0.7),
                Color(red: 0.95, green: 0.7, blue: 0.6),
                Color(red: 0.9, green: 0.6, blue: 0.5).opacity(0.8)
            ]
        default:  // Night - Deep blues/indigo
            return [
                Color(red: 0.2, green: 0.2, blue: 0.4),
                Color(red: 0.15, green: 0.15, blue: 0.35),
                Color(red: 0.1, green: 0.1, blue: 0.3).opacity(0.8)
            ]
        }
    }
    
    // MARK: - Glacier Layers
    
    private var glacierLayer1: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { _ in
            Canvas { context, size in
                let time = Date().timeIntervalSince1970
                
                // Create flowing glacier shapes
                for i in 0..<3 {
                    let path = createGlacierPath(
                        in: size,
                        time: time * 0.05 + Double(i),
                        amplitude: 150,
                        frequency: 0.002,
                        phase: phase1
                    )
                    
                    context.fill(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                glacierColor(for: currentHour).opacity(0.3),
                                glacierColor(for: currentHour).opacity(0.15),
                                Color.clear
                            ]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: size.width, y: size.height)
                        )
                    )
                }
            }
        }
        .blur(radius: 40)
    }
    
    private var glacierLayer2: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { _ in
            Canvas { context, size in
                let time = Date().timeIntervalSince1970
                
                for i in 0..<2 {
                    let path = createGlacierPath(
                        in: size,
                        time: time * 0.03 + Double(i) * 1.5,
                        amplitude: 200,
                        frequency: 0.0015,
                        phase: phase2
                    )
                    
                    context.fill(
                        path,
                        with: .radialGradient(
                            Gradient(colors: [
                                glacierColor(for: currentHour).opacity(0.4),
                                glacierColor(for: currentHour).opacity(0.2),
                                Color.clear
                            ]),
                            center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                            startRadius: 100,
                            endRadius: 400
                        )
                    )
                }
            }
        }
        .blur(radius: 60)
        .opacity(0.7)
    }
    
    private var glacierLayer3: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { _ in
            Canvas { context, size in
                let time = Date().timeIntervalSince1970
                
                let path = createGlacierPath(
                    in: size,
                    time: time * 0.02,
                    amplitude: 250,
                    frequency: 0.001,
                    phase: phase3
                )
                
                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            glacierColor(for: currentHour).opacity(0.25),
                            Color.clear
                        ]),
                        startPoint: CGPoint(x: size.width, y: 0),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }
        }
        .blur(radius: 80)
        .opacity(0.5)
    }
    
    // MARK: - Ice Particles
    
    private var iceParticleLayer: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { _ in
            Canvas { context, size in
                for particle in iceParticles {
                    let opacity = particle.opacity * 0.3
                    
                    context.fill(
                        Circle().path(in: CGRect(
                            x: particle.position.x - particle.size / 2,
                            y: particle.position.y - particle.size / 2,
                            width: particle.size,
                            height: particle.size
                        )),
                        with: .color(Color.white.opacity(opacity))
                    )
                }
            }
        }
        .blur(radius: 1)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    updateIceParticles()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createGlacierPath(in size: CGSize, time: Double, amplitude: CGFloat, frequency: CGFloat, phase: CGFloat) -> Path {
        var path = Path()
        
        let steps = Int(size.width / 5)
        var points: [CGPoint] = []
        
        for i in 0...steps {
            let x = CGFloat(i) * size.width / CGFloat(steps)
            let baseY = size.height * 0.5
            
            // Multiple sine waves for organic movement
            let y1 = sin(x * frequency + time + phase) * amplitude
            let y2 = sin(x * frequency * 1.5 + time * 0.7 + phase) * amplitude * 0.5
            let y3 = sin(x * frequency * 0.5 + time * 1.3 + phase) * amplitude * 0.3
            
            let y = baseY + y1 + y2 + y3
            points.append(CGPoint(x: x, y: y))
        }
        
        // Create smooth bezier curve through points
        path.move(to: CGPoint(x: 0, y: size.height))
        path.addLine(to: points[0])
        
        for i in 1..<points.count {
            let previousPoint = points[i - 1]
            let currentPoint = points[i]
            let midPoint = CGPoint(
                x: (previousPoint.x + currentPoint.x) / 2,
                y: (previousPoint.y + currentPoint.y) / 2
            )
            
            path.addQuadCurve(to: midPoint, control: previousPoint)
        }
        
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        
        return path
    }
    
    private func glacierColor(for hour: Int) -> Color {
        switch hour {
        case 5..<12: return Color(red: 0.5, green: 0.8, blue: 1.0).opacity(0.6)  // Sky blue
        case 12..<17: return Color.yellow.opacity(0.6)                           // Yellow
        case 17..<21: return Color.orange.opacity(0.6)                           // Orange sunset
        default: return Color.indigo.opacity(0.7)                                // Indigo night
        }
    }
    
    private func startAnimations() {
        withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) {
            phase1 = .pi * 2
        }
        
        withAnimation(.linear(duration: 150).repeatForever(autoreverses: false)) {
            phase2 = .pi * 2
        }
        
        withAnimation(.linear(duration: 180).repeatForever(autoreverses: false)) {
            phase3 = .pi * 2
        }
    }
    
    private func generateIceParticles() {
        for _ in 0..<30 {
            iceParticles.append(IceParticle())
        }
    }
    
    private func updateIceParticles() {
        for i in iceParticles.indices {
            iceParticles[i].update()
            
            // Regenerate particle if it's faded out or moved off screen
            if iceParticles[i].opacity <= 0 || iceParticles[i].position.y > 1000 {
                iceParticles[i] = IceParticle()
            }
        }
    }
}

// MARK: - Ice Particle

struct IceParticle {
    var position: CGPoint
    var velocity: CGVector
    var size: CGFloat
    var opacity: Double
    let driftSpeed: CGFloat
    
    init() {
        position = CGPoint(
            x: CGFloat.random(in: 0...1200),
            y: CGFloat.random(in: -100...800)
        )
        velocity = CGVector(
            dx: CGFloat.random(in: -10...10),
            dy: CGFloat.random(in: 5...20)
        )
        size = CGFloat.random(in: 1...3)
        opacity = Double.random(in: 0.3...0.8)
        driftSpeed = CGFloat.random(in: 0.5...2)
    }
    
    mutating func update() {
        // Gentle downward drift with slight horizontal movement
        position.x += velocity.dx * 0.1 + sin(position.y * 0.01) * driftSpeed
        position.y += velocity.dy * 0.1
        
        // Slowly fade out
        opacity -= 0.001
    }
}

// MARK: - Preview

struct GlacierBackground_Previews: PreviewProvider {
    static var previews: some View {
        GlacierBackground()
            .frame(width: 1200, height: 800)
    }
}