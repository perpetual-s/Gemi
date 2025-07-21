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
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 40) {
                Spacer()
                
                // Model icon with animation
                modelIcon
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.8)
                    .animation(.spring(duration: 0.8).delay(0.2), value: showContent)
                
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
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.spring(duration: 0.8).delay(0.4), value: showContent)
                
                Spacer()
                
                // Skip button (only during setup)
                if !setupManager.isComplete && hasStartedSetup {
                    skipButton
                        .opacity(showContent ? 1 : 0)
                        .animation(.spring(duration: 0.8).delay(0.6), value: showContent)
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
                
                // Show celebration
                withAnimation(.spring()) {
                    showingCelebration = true
                }
                
                // Complete after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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
    @State private var showParticles = false
    
    var body: some View {
        ZStack {
            // Success checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(showParticles ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showParticles)
            
            // Particle effects
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(Color.random)
                    .frame(width: 10, height: 10)
                    .offset(
                        x: showParticles ? CGFloat.random(in: -200...200) : 0,
                        y: showParticles ? CGFloat.random(in: -200...200) : 0
                    )
                    .opacity(showParticles ? 0 : 1)
                    .scaleEffect(showParticles ? CGFloat.random(in: 0.5...1.5) : 0)
                    .animation(
                        .spring(response: 1.0, dampingFraction: 0.5)
                        .delay(Double(index) * 0.02),
                        value: showParticles
                    )
            }
        }
        .onAppear {
            showParticles = true
        }
    }
}

extension Color {
    static var random: Color {
        let colors: [Color] = [.blue, .purple, .pink, .mint, .green, .yellow, .orange]
        return colors.randomElement() ?? .blue
    }
}