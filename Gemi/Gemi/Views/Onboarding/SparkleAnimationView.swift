import SwiftUI

struct SparkleAnimationView: View {
    @State private var animationPhase = 0.0
    @State private var pulseScale = 1.0
    @State private var sparkleOpacity = 0.3
    @State private var glowRadius = 20.0
    @State private var centralRotation = 0.0
    @State private var centralScale = 1.0
    
    // Performance optimization: pre-calculate particle positions
    private let particleCount = 6
    private let baseRadius: CGFloat = 60
    
    var body: some View {
        ZStack {
            // Background glow effect using Theme colors
            Circle()
                .fill(Theme.Gradients.aurora)
                .frame(width: 200, height: 200)
                .blur(radius: glowRadius)
                .scaleEffect(pulseScale)
            
            // Orbiting sparkles with optimized animation
            ForEach(0..<particleCount, id: \.self) { index in
                SparkleParticle(
                    index: index,
                    animationPhase: animationPhase,
                    particleCount: particleCount,
                    baseRadius: baseRadius
                )
            }
            
            // Central emoji with state-based animation
            Text("✨")
                .font(.system(size: 100))
                .scaleEffect(centralScale)
                .rotationEffect(.degrees(centralRotation))
                .shadow(color: Theme.Colors.glowColor, radius: 10)
        }
        .onAppear {
            // Use Theme animation constants
            withAnimation(Theme.delightfulBounce.repeatForever(autoreverses: true)) {
                pulseScale = 1.2
                glowRadius = 30
            }
            
            withAnimation(Theme.smoothAnimation.repeatForever(autoreverses: true)) {
                centralScale = 1.05
            }
            
            withAnimation(Theme.morphAnimation.repeatForever(autoreverses: false)) {
                centralRotation = 5
            }
            
            // Single animation driver for particles
            withAnimation(Animation.linear(duration: 10).repeatForever(autoreverses: false)) {
                animationPhase = 360
            }
        }
    }
}

struct SparkleParticle: View {
    let index: Int
    let animationPhase: Double
    let particleCount: Int
    let baseRadius: CGFloat
    
    @State private var particleScale = 1.0
    @State private var particleOpacity = 0.5
    @State private var particleRotation = 0.0
    
    // Calculate static position based on index
    private var baseAngle: Double {
        (Double(index) / Double(particleCount)) * 360
    }
    
    private var xPosition: CGFloat {
        100 + cos((baseAngle + animationPhase) * .pi / 180) * baseRadius
    }
    
    private var yPosition: CGFloat {
        100 + sin((baseAngle + animationPhase) * .pi / 180) * baseRadius
    }
    
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 20))
            .foregroundStyle(
                index % 2 == 0 ? Theme.Gradients.primary : Theme.Gradients.aurora
            )
            .scaleEffect(particleScale)
            .opacity(particleOpacity)
            .rotationEffect(.degrees(particleRotation))
            .position(x: xPosition, y: yPosition)
            .shadow(color: Theme.Colors.glowColor, radius: 3)
            .frame(width: 200, height: 200)
            .onAppear {
                // Stagger animations for visual interest
                let delay = Double(index) * 0.1
                
                withAnimation(Theme.gentleSpring.repeatForever(autoreverses: true).delay(delay)) {
                    particleScale = 1.3
                    particleOpacity = 0.8
                }
                
                withAnimation(Animation.linear(duration: 3).repeatForever(autoreverses: false).delay(delay)) {
                    particleRotation = index % 2 == 0 ? 360 : -360
                }
            }
    }
}