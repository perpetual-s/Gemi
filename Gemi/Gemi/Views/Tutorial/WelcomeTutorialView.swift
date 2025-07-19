import SwiftUI

/// An interactive tutorial overlay for first-time users
struct WelcomeTutorialView: View {
    @Binding var showTutorial: Bool
    @State private var currentStep = 0
    @State private var animateSpotlight = false
    
    let steps: [TutorialStep] = [
        TutorialStep(
            id: 0,
            title: "Welcome to Your Private Diary",
            message: "Let's take a quick tour of Gemi. Everything you write stays on your device.",
            targetArea: .fullScreen,
            highlightRect: nil
        ),
        TutorialStep(
            id: 1,
            title: "Create Your First Entry",
            message: "Click here or press ⌘N to start writing. Your thoughts are automatically saved.",
            targetArea: .composeButton,
            highlightRect: CGRect(x: 150, y: 100, width: 200, height: 50)
        ),
        TutorialStep(
            id: 2,
            title: "Chat with Your AI Companion",
            message: "Press ⌘T to talk with Gemi. It remembers your past entries and offers thoughtful insights.",
            targetArea: .chatButton,
            highlightRect: CGRect(x: 150, y: 160, width: 200, height: 50)
        ),
        TutorialStep(
            id: 3,
            title: "Browse Your Timeline",
            message: "All your entries appear here, organized by date. Click any entry to read or edit.",
            targetArea: .timeline,
            highlightRect: CGRect(x: 400, y: 100, width: 300, height: 400)
        ),
        TutorialStep(
            id: 4,
            title: "Quick Actions",
            message: "Press ⌘K to open the command palette for quick access to any feature.",
            targetArea: .commandPalette,
            highlightRect: nil
        )
    ]
    
    var body: some View {
        ZStack {
            // Dark overlay with spotlight cutout
            if currentStep < steps.count {
                SpotlightOverlay(
                    highlightRect: steps[currentStep].highlightRect,
                    animate: animateSpotlight
                )
                .allowsHitTesting(false)
                .transition(.opacity)
            }
            
            // Tutorial content
            if currentStep < steps.count {
                tutorialContent(for: steps[currentStep])
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
        .onAppear {
            animateSpotlight = true
        }
    }
    
    @ViewBuilder
    private func tutorialContent(for step: TutorialStep) -> some View {
        VStack(spacing: 0) {
            if step.targetArea == .fullScreen || step.highlightRect == nil {
                // Center content for full screen steps
                Spacer()
                
                TutorialCard(
                    step: step,
                    currentStep: currentStep,
                    totalSteps: steps.count,
                    onNext: nextStep,
                    onSkip: skipTutorial
                )
                .frame(maxWidth: 500)
                
                Spacer()
            } else {
                // Position near highlighted area
                GeometryReader { geometry in
                    TutorialCard(
                        step: step,
                        currentStep: currentStep,
                        totalSteps: steps.count,
                        onNext: nextStep,
                        onSkip: skipTutorial
                    )
                    .frame(maxWidth: 400)
                    .position(
                        x: positionForStep(step, in: geometry).x,
                        y: positionForStep(step, in: geometry).y
                    )
                }
            }
        }
    }
    
    private func positionForStep(_ step: TutorialStep, in geometry: GeometryProxy) -> CGPoint {
        guard let rect = step.highlightRect else {
            return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        
        // Position the card near the highlighted area
        let centerX = rect.midX
        let cardY = rect.maxY + 40 // Below the highlighted area
        
        // Ensure card stays within bounds
        let x = min(max(200, centerX), geometry.size.width - 200)
        let y = min(cardY, geometry.size.height - 200)
        
        return CGPoint(x: x, y: y)
    }
    
    private func nextStep() {
        if currentStep < steps.count - 1 {
            currentStep += 1
        } else {
            skipTutorial()
        }
    }
    
    private func skipTutorial() {
        withAnimation(.easeOut(duration: 0.3)) {
            showTutorial = false
        }
        
        // Mark tutorial as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedTutorial")
    }
}

// MARK: - Tutorial Step Model

struct TutorialStep {
    let id: Int
    let title: String
    let message: String
    let targetArea: TargetArea
    let highlightRect: CGRect?
    
    enum TargetArea {
        case fullScreen
        case composeButton
        case chatButton
        case timeline
        case commandPalette
    }
}

// MARK: - Tutorial Card

struct TutorialCard: View {
    let step: TutorialStep
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void
    
    @State private var appear = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? Color.white : Color.white.opacity(0.3))
                        .frame(height: 4)
                        .frame(maxWidth: 40)
                }
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 16) {
                // Icon for step
                Image(systemName: iconForStep(step))
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(appear ? 1 : 0.5)
                    .opacity(appear ? 1 : 0)
                    .animation(.spring(response: 0.4).delay(0.1), value: appear)
                
                // Title
                Text(step.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)
                    .animation(.spring(response: 0.4).delay(0.2), value: appear)
                
                // Message
                Text(step.message)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)
                    .animation(.spring(response: 0.4).delay(0.3), value: appear)
            }
            .padding(.horizontal, 20)
            
            // Actions
            HStack(spacing: 16) {
                Button {
                    onSkip()
                } label: {
                    Text("Skip Tour")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    onNext()
                } label: {
                    HStack(spacing: 8) {
                        Text(currentStep == totalSteps - 1 ? "Get Started" : "Next")
                            .font(.system(size: 16, weight: .medium))
                        
                        if currentStep < totalSteps - 1 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.white)
                    )
                }
                .buttonStyle(.plain)
                .scaleEffect(appear ? 1 : 0.8)
                .opacity(appear ? 1 : 0)
                .animation(.spring(response: 0.4).delay(0.4), value: appear)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.9))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        )
        .onAppear {
            appear = true
        }
        .onChange(of: currentStep) { _ in
            appear = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appear = true
            }
        }
    }
    
    private func iconForStep(_ step: TutorialStep) -> String {
        switch step.targetArea {
        case .fullScreen:
            return "sparkles"
        case .composeButton:
            return "square.and.pencil"
        case .chatButton:
            return "bubble.left.and.bubble.right"
        case .timeline:
            return "clock"
        case .commandPalette:
            return "command"
        }
    }
}

// MARK: - Spotlight Overlay

struct SpotlightOverlay: View {
    let highlightRect: CGRect?
    let animate: Bool
    
    var body: some View {
        Canvas { context, size in
            // Draw dark overlay
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.75))
            )
            
            // Cut out spotlight area if provided
            if let rect = highlightRect {
                let expandedRect = rect.insetBy(dx: -10, dy: -10)
                
                context.blendMode = .destinationOut
                context.fill(
                    RoundedRectangle(cornerRadius: 12)
                        .path(in: expandedRect),
                    with: .color(.white)
                )
                
                // Add glow effect
                context.blendMode = .normal
                context.stroke(
                    RoundedRectangle(cornerRadius: 12)
                        .path(in: expandedRect),
                    with: .color(.white.opacity(animate ? 0.3 : 0.1)),
                    style: StrokeStyle(lineWidth: animate ? 3 : 1)
                )
            }
        }
        .animation(
            .easeInOut(duration: 2)
            .repeatForever(autoreverses: true),
            value: animate
        )
    }
}

// MARK: - Preview

struct WelcomeTutorialView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3)
            
            WelcomeTutorialView(showTutorial: .constant(true))
        }
        .frame(width: 900, height: 700)
    }
}