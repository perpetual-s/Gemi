import SwiftUI

/// Simplified setup progress view for bundled Gemma 3n model
struct SimplifiedSetupProgressView: View {
    @StateObject private var setupManager = SimplifiedModelSetupService()
    let onComplete: () -> Void
    let onSkip: () -> Void
    
    @State private var showingError = false
    @State private var pulseAnimation = false
    @State private var hasCalledCompletion = false
    @State private var contentOpacity: Double = 0.0
    @State private var hasStartedSetup = false
    @State private var showContent = false
    @State private var showingCelebration = false
    @State private var hideContentForCelebration = false
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 40) {
                Spacer()
                
                // Model icon with animation
                modelIcon
                    .opacity(showContent && !hideContentForCelebration ? 1 : 0)
                    .scaleEffect(showContent && !hideContentForCelebration ? 1 : 0.8)
                    .animation(.spring(duration: 0.8).delay(0.2), value: showContent)
                    .animation(.easeOut(duration: 0.3), value: hideContentForCelebration)
                
                // Progress content
                VStack(spacing: 30) {
                    // Current step
                    Text(setupManager.currentStep.description)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    // Progress bar
                    ProgressView(value: setupManager.progress)
                        .progressViewStyle(GemmaProgressViewStyle())
                        .frame(width: 300)
                    
                    // Status message
                    Text(setupManager.statusMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                .opacity(showContent && !hideContentForCelebration ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.spring(duration: 0.8).delay(0.4), value: showContent)
                .animation(.easeOut(duration: 0.3), value: hideContentForCelebration)
                
                Spacer()
                
                // Skip button (only during setup)
                if !setupManager.isComplete && hasStartedSetup {
                    skipButton
                        .opacity(showContent && !hideContentForCelebration ? 1 : 0)
                        .animation(.spring(duration: 0.8).delay(0.6), value: showContent)
                        .animation(.easeOut(duration: 0.3), value: hideContentForCelebration)
                }
            }
            .padding(50)
            .opacity(contentOpacity)
            
            // Celebration overlay
            if showingCelebration {
                CelebrationOverlay()
            }
        }
        .frame(width: 900, height: 700)
        .background(Theme.Colors.windowBackground)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                contentOpacity = 1.0
                showContent = true
            }
            
            if !hasStartedSetup {
                hasStartedSetup = true
                setupManager.startSetup()
            }
        }
        .onChange(of: setupManager.isComplete) { oldValue, newValue in
            if newValue && !hasCalledCompletion && !oldValue {
                hasCalledCompletion = true
                
                // First hide the content
                withAnimation(.easeOut(duration: 0.3)) {
                    hideContentForCelebration = true
                }
                
                // Then show celebration after a slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showingCelebration = true
                    }
                }
                
                // Complete after celebration
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    onComplete()
                }
            }
        }
        .alert("Setup Error", isPresented: $showingError) {
            Button("Retry") {
                setupManager.startSetup()
            }
            Button("Skip", role: .cancel) {
                onSkip()
            }
        } message: {
            if let error = setupManager.error {
                Text(error.localizedDescription)
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                }
            }
        }
        .onChange(of: setupManager.error) { oldValue, newValue in
            showingError = newValue != nil
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.05, blue: 0.2),
                Color(red: 0.05, green: 0.05, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var modelIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .blur(radius: 30)
                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
            
            Image(systemName: "brain")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .blue.opacity(0.5), radius: 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
    
    private var skipButton: some View {
        Button(action: onSkip) {
            HStack {
                Text("Skip Setup")
                    .font(.system(size: 14))
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
            }
            .foregroundColor(.white.opacity(0.6))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help("Skip setup and continue to the app")
    }
}

// Progress view style
struct GemmaProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.1))
                .frame(height: 8)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: CGFloat(configuration.fractionCompleted ?? 0) * 300, height: 8)
                .animation(.spring(), value: configuration.fractionCompleted)
        }
    }
}

// Celebration overlay
struct CelebrationOverlay: View {
    @State private var showCheckmark = false
    @State private var showParticles = false
    @State private var showGlow = false
    @State private var showSuccessText = false
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .blur(radius: 10)
            
            VStack(spacing: 30) {
                // Success checkmark with glow
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.green.opacity(0.5),
                                    Color.green.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                        .opacity(showGlow ? 1 : 0)
                        .scaleEffect(showGlow ? 1.5 : 0.5)
                    
                    // Checkmark circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.8, blue: 0.4),
                                    Color(red: 0.3, green: 0.9, blue: 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .green.opacity(0.5), radius: 20)
                        .scaleEffect(showCheckmark ? 1 : 0)
                        .rotationEffect(.degrees(showCheckmark ? 0 : -90))
                    
                    // Checkmark icon
                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(showCheckmark ? 1 : 0)
                        .rotationEffect(.degrees(showCheckmark ? 0 : -90))
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showCheckmark)
                .animation(.easeOut(duration: 0.8).delay(0.2), value: showGlow)
                
                // Success text
                Text("Model Loaded Successfully!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .opacity(showSuccessText ? 1 : 0)
                    .offset(y: showSuccessText ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.5), value: showSuccessText)
            }
            
            // Particle effects
            ForEach(0..<30, id: \.self) { index in
                ParticleView(index: index, show: showParticles)
            }
        }
        .onAppear {
            showCheckmark = true
            showGlow = true
            showSuccessText = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showParticles = true
            }
        }
    }
}

// Individual particle view
struct ParticleView: View {
    let index: Int
    let show: Bool
    
    @State private var finalX: CGFloat = 0
    @State private var finalY: CGFloat = 0
    @State private var finalScale: CGFloat = 1
    @State private var color: Color = .green
    
    var body: some View {
        Circle()
            .fill(color.opacity(0.8))
            .frame(width: 12, height: 12)
            .offset(
                x: show ? finalX : 0,
                y: show ? finalY : 0
            )
            .scaleEffect(show ? finalScale : 0)
            .opacity(show ? 0 : 1)
            .animation(
                .easeOut(duration: 1.5)
                .delay(Double(index) * 0.02),
                value: show
            )
            .onAppear {
                finalX = CGFloat.random(in: -250...250)
                finalY = CGFloat.random(in: -250...250)
                finalScale = CGFloat.random(in: 0.5...1.2)
                
                let colors: [Color] = [
                    .green, .mint, .blue.opacity(0.8), 
                    .purple.opacity(0.8), .yellow.opacity(0.8)
                ]
                color = colors.randomElement() ?? .green
            }
    }
}

