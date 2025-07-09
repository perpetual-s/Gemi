import SwiftUI

/// Beautiful empty state view with time-based illustrations and writing prompts
struct EmptyStateView: View {
    @State private var currentPrompt: String = ""
    @State private var promptOpacity = 0.0
    @State private var illustrationScale = 0.8
    @State private var particleAnimation = false
    @State private var quote: (text: String, author: String) = ("", "")
    
    private let promptGenerator = WritingPromptGenerator.shared
    private let timer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()
    
    var timeOfDay: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
    
    enum TimeOfDay {
        case morning, afternoon, evening, night
        
        var illustration: String {
            switch self {
            case .morning: return "sun.max"
            case .afternoon: return "sun.and.horizon"
            case .evening: return "sunset"
            case .night: return "moon.stars"
            }
        }
        
        var colors: [Color] {
            switch self {
            case .morning: return [.orange.opacity(0.3), .yellow.opacity(0.2)]
            case .afternoon: return [.blue.opacity(0.2), .cyan.opacity(0.15)]
            case .evening: return [.purple.opacity(0.3), .pink.opacity(0.2)]
            case .night: return [.indigo.opacity(0.4), .purple.opacity(0.3)]
            }
        }
        
        var greeting: String {
            switch self {
            case .morning: return "Good morning"
            case .afternoon: return "Good afternoon"
            case .evening: return "Good evening"
            case .night: return "Good night"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background
            animatedBackground
            
            // Floating particles
            if particleAnimation {
                ParticleEmitterView()
                    .allowsHitTesting(false)
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Time-based illustration
                illustrationView
                
                // Welcome message
                welcomeSection
                
                // Writing prompt
                promptSection
                
                // CTA Button
                startWritingButton
                
                Spacer()
                
                // Inspirational quote
                quoteSection
            }
            .padding(40)
        }
        .onAppear {
            animateIn()
            loadNewPrompt()
            quote = InspirationQuotes.random()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                promptOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                loadNewPrompt()
                withAnimation(.easeInOut(duration: 0.6)) {
                    promptOpacity = 1
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var animatedBackground: some View {
        LinearGradient(
            colors: timeOfDay.colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 3), value: timeOfDay.colors)
        .overlay(
            // Subtle moving gradient
            GeometryReader { geometry in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.1), Color.clear],
                            center: .center,
                            startRadius: 50,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: sin(Date().timeIntervalSince1970 * 0.1) * 50)
                    .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: Date())
                    .blur(radius: 40)
            }
        )
    }
    
    private var illustrationView: some View {
        VStack(spacing: 20) {
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [timeOfDay.colors[0], Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                
                // Main icon
                Image(systemName: timeOfDay.illustration)
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [timeOfDay.colors[0], timeOfDay.colors[1]],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(illustrationScale)
                    .shadow(color: timeOfDay.colors[0].opacity(0.5), radius: 20)
            }
            
            Text(timeOfDay.greeting)
                .font(Theme.Typography.greeting)
                .foregroundColor(.primary.opacity(0.8))
        }
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 12) {
            Text("Your journal awaits")
                .font(Theme.Typography.heroTitle)
                .foregroundColor(.primary)
            
            Text("Every great story begins with a single word")
                .font(Theme.Typography.subtitle)
                .foregroundColor(.secondary)
        }
    }
    
    private var promptSection: some View {
        VStack(spacing: 16) {
            Text("Need inspiration?")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(currentPrompt)
                .font(.system(size: 20, weight: .light, design: .serif))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(promptOpacity)
                .frame(minHeight: 60)
                .padding(.horizontal, 20)
        }
    }
    
    private var startWritingButton: some View {
        Button {
            NotificationCenter.default.post(name: .newEntry, object: nil)
            
            // Trigger haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(
                .levelChange,
                performanceTime: .default
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 18))
                
                Text("Start Writing")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: Color.blue.opacity(0.3), radius: 15, y: 5)
        }
        .buttonStyle(PressButtonStyle())
    }
    
    private var quoteSection: some View {
        VStack(spacing: 8) {
            Text("\"\(quote.text)\"")
                .font(.system(size: 16, weight: .light, design: .serif))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .italic()
            
            Text("— \(quote.author)")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(.horizontal, 40)
        .opacity(0.8)
    }
    
    // MARK: - Methods
    
    private func animateIn() {
        withAnimation(.spring(response: 1, dampingFraction: 0.8).delay(0.2)) {
            illustrationScale = 1.0
        }
        
        withAnimation(.easeInOut(duration: 0.8).delay(0.5)) {
            promptOpacity = 1.0
        }
        
        withAnimation(.easeInOut(duration: 1).delay(0.8)) {
            particleAnimation = true
        }
    }
    
    private func loadNewPrompt() {
        currentPrompt = promptGenerator.getCurrentPrompt()
    }
}

// MARK: - Particle Effect

struct ParticleEmitterView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        
        let emitterLayer = CAEmitterLayer()
        emitterLayer.emitterPosition = CGPoint(x: view.bounds.width / 2, y: view.bounds.height)
        emitterLayer.emitterSize = CGSize(width: view.bounds.width, height: 1)
        emitterLayer.emitterShape = .line
        
        let cell = CAEmitterCell()
        cell.birthRate = 0.5
        cell.lifetime = 20
        cell.velocity = 50
        cell.velocityRange = 20
        cell.emissionRange = .pi / 4
        cell.spin = 0.5
        cell.spinRange = 1
        cell.scale = 0.05
        cell.scaleRange = 0.05
        cell.alphaSpeed = -0.05
        
        // Create a small circle as particle
        let image = NSImage(size: NSSize(width: 20, height: 20))
        image.lockFocus()
        NSColor.white.withAlphaComponent(0.3).set()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: 20, height: 20)).fill()
        image.unlockFocus()
        
        cell.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        emitterLayer.emitterCells = [cell]
        
        view.layer?.addSublayer(emitterLayer)
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Button Style

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    EmptyStateView()
        .frame(width: 800, height: 600)
}