import SwiftUI

struct SparkleAnimationView: View {
    @State private var animationPhase = 0.0
    @State private var pulseScale = 1.0
    @State private var sparkleOpacity = 0.3
    @State private var glowRadius = 20.0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSince1970
            
            ZStack {
                // Background glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.4),
                                Color.blue.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: glowRadius)
                    .scaleEffect(pulseScale)
                
                // Orbiting sparkles
                ForEach(0..<6) { index in
                    SparkleParticle(index: index, time: time)
                }
                
                // Central emoji with subtle animation
                Text("✨")
                    .font(.system(size: 100))
                    .scaleEffect(1.0 + sin(time * 2) * 0.05)
                    .rotationEffect(.degrees(sin(time * 0.5) * 5))
                    .shadow(color: .white.opacity(0.8), radius: 10)
                    .shadow(color: .purple.opacity(0.6), radius: 20)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.2
                    sparkleOpacity = 0.8
                    glowRadius = 30
                }
            }
        }
    }
}

struct SparkleParticle: View {
    let index: Int
    let time: Double
    
    private var angle: Double {
        (Double(index) / 6.0) * 360 + time * 30
    }
    
    private var radius: Double {
        60 + sin(time * 2 + Double(index)) * 10
    }
    
    private var particleSize: Double {
        20 + sin(time * 3 + Double(index) * 0.5) * 5
    }
    
    private var opacity: Double {
        0.5 + sin(time * 2 + Double(index) * 0.3) * 0.3
    }
    
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: particleSize))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        index % 2 == 0 ? Color.purple : Color.blue,
                        index % 2 == 0 ? Color.pink : Color.cyan
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .opacity(opacity)
            .position(
                x: 100 + cos(angle * .pi / 180) * radius,
                y: 100 + sin(angle * .pi / 180) * radius
            )
            .rotationEffect(.degrees(time * 60 * (index % 2 == 0 ? 1 : -1)))
            .shadow(color: .white.opacity(0.6), radius: 3)
            .frame(width: 200, height: 200)
    }
}