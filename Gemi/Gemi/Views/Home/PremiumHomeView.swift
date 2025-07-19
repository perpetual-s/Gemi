import SwiftUI

/// Premium home view with award-winning animations and interactions
struct PremiumHomeView: View {
    @StateObject private var databaseManager = DatabaseManager.shared
    @State private var hoveredCard: String? = nil
    @State private var heroScale: CGFloat = 0.8
    @State private var heroOpacity: Double = 0
    @State private var cardsOffset: CGFloat = 50
    @State private var cardsOpacity: Double = 0
    @State private var mouseLocation: CGPoint = .zero
    @State private var particleSystem = HomeParticleSystem()
    @State private var showTutorial = false
    
    // Animation states
    @State private var floatingOrbs: [FloatingOrb] = []
    @State private var cardRotations: [String: Double] = [:]
    @State private var magneticOffset: [String: CGSize] = [:]
    @State private var pulseAnimation = false
    
    let onNewEntry: () -> Void
    let onOpenChat: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic gradient background
                dynamicBackground
                
                // Parallax floating orbs
                parallaxOrbsLayer(in: geometry)
                
                // Interactive particles
                ParticleFieldView(
                    mouseLocation: mouseLocation,
                    particleSystem: particleSystem
                )
                .allowsHitTesting(false)
                
                // Main content with scroll
                ScrollView {
                    VStack(spacing: 40) {
                        // Hero section with enhanced animations
                        heroSection
                            .padding(.top, 60)
                        
                        // Premium quick actions grid
                        premiumQuickActionsGrid(in: geometry)
                            .padding(.horizontal, 40)
                        
                        // Stats section with animations
                        if hasEntries {
                            statsSection
                                .padding(.horizontal, 40)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                                    removal: .scale(scale: 1.1).combined(with: .opacity)
                                ))
                        }
                    }
                    .padding(.bottom, 40)
                }
                .scrollBounceBehavior(.basedOnSize)
                
                // First-time tutorial overlay
                if showTutorial && !hasCompletedTutorial {
                    WelcomeTutorialView(showTutorial: $showTutorial)
                        .transition(.opacity)
                }
            }
            .onAppear {
                startAnimations()
                checkFirstTimeUser()
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    mouseLocation = location
                    particleSystem.attractorPosition = location
                case .ended:
                    particleSystem.attractorPosition = nil
                }
            }
        }
    }
    
    // MARK: - Dynamic Background
    
    private var dynamicBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 5), value: currentHour)
            
            // Animated mesh gradient overlay
            TimelineView(.animation(minimumInterval: 0.1)) { _ in
                Canvas { context, size in
                    let time = Date().timeIntervalSince1970
                    
                    for i in 0..<3 {
                        let phase = Double(i) * 2.1
                        let x = size.width * 0.5 + sin(time * 0.3 + phase) * size.width * 0.3
                        let y = size.height * 0.5 + cos(time * 0.4 + phase) * size.height * 0.3
                        
                        let gradient = RadialGradient(
                            colors: [
                                Theme.Colors.ambientColor(for: currentHour).opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 300
                        )
                        
                        context.fill(
                            Circle().path(in: CGRect(x: x - 150, y: y - 150, width: 300, height: 300)),
                            with: .radialGradient(
                                Gradient(colors: [
                                    Theme.Colors.ambientColor(for: currentHour).opacity(0.3),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 50,
                                endRadius: 150
                            )
                        )
                    }
                }
                .blur(radius: 60)
                .opacity(0.6)
            }
        }
    }
    
    // MARK: - Parallax Orbs
    
    private func parallaxOrbsLayer(in geometry: GeometryProxy) -> some View {
        ForEach(floatingOrbs) { orb in
            FloatingOrbView(orb: orb, mouseLocation: mouseLocation)
                .offset(
                    x: (mouseLocation.x - geometry.size.width / 2) * orb.parallaxFactor,
                    y: (mouseLocation.y - geometry.size.height / 2) * orb.parallaxFactor
                )
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 12) {
            // Animated icon with pulse
            ZStack {
                // Multi-layer glow
                ForEach(0..<4) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    iconColor.opacity(0.4 - Double(index) * 0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80 + CGFloat(index * 20)
                            )
                        )
                        .frame(width: 160 + CGFloat(index * 40), height: 160 + CGFloat(index * 40))
                        .blur(radius: 20)
                        .scaleEffect(pulseAnimation ? 1.1 : 0.95)
                        .animation(
                            .easeInOut(duration: 3 + Double(index))
                            .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }
                
                // Central icon
                TimeBasedIcon(hour: currentHour)
                    .scaleEffect(heroScale)
                    .rotationEffect(.degrees(sin(Date().timeIntervalSince1970 * 0.2) * 5))
            }
            .opacity(heroOpacity)
            
            // Animated greeting
            VStack(spacing: 8) {
                Text(greeting)
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primary, Color.primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 2)
                
                HStack(spacing: 4) {
                    ForEach(Array("Ready to capture today's moments?".enumerated()), id: \.offset) { index, character in
                        Text(String(character))
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.secondary)
                            .offset(y: sin(Date().timeIntervalSince1970 * 2 + Double(index) * 0.1) * 2)
                    }
                }
            }
            .opacity(heroOpacity)
        }
    }
    
    // MARK: - Premium Quick Actions Grid
    
    private func premiumQuickActionsGrid(in geometry: GeometryProxy) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
            // New Entry card
            MagneticActionCard(
                id: "new",
                title: "New Entry",
                subtitle: "Start writing",
                icon: "pencil.and.outline",
                color: .blue,
                mouseLocation: mouseLocation,
                cardCenter: CGPoint(x: geometry.size.width * 0.25, y: 400),
                action: onNewEntry
            )
            
            // Chat card
            MagneticActionCard(
                id: "chat",
                title: "Talk to Gemi",
                subtitle: "AI conversation",
                icon: "bubble.left.and.bubble.right.fill",
                color: .purple,
                mouseLocation: mouseLocation,
                cardCenter: CGPoint(x: geometry.size.width * 0.75, y: 400),
                action: onOpenChat
            )
            
            // Timeline card
            MagneticActionCard(
                id: "timeline",
                title: "Timeline",
                subtitle: "\(entryCount) entries",
                icon: "clock.fill",
                color: .orange,
                mouseLocation: mouseLocation,
                cardCenter: CGPoint(x: geometry.size.width * 0.25, y: 520),
                action: {}
            )
            
            // Insights card
            MagneticActionCard(
                id: "insights",
                title: "Insights",
                subtitle: "Your patterns",
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                mouseLocation: mouseLocation,
                cardCenter: CGPoint(x: geometry.size.width * 0.75, y: 520),
                action: {}
            )
        }
        .offset(y: cardsOffset)
        .opacity(cardsOpacity)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(spacing: 16) {
            Text("Your Journey")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary)
            
            HStack(spacing: 20) {
                StatCard(
                    value: "\(entryCount)",
                    label: "Entries",
                    icon: "doc.text.fill",
                    color: .blue
                )
                
                StatCard(
                    value: streakText,
                    label: "Current Streak",
                    icon: "flame.fill",
                    color: .orange
                )
                
                StatCard(
                    value: "\(databaseManager.memories.count)",
                    label: "Memories",
                    icon: "sparkles",
                    color: .purple
                )
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
    }
    
    // MARK: - Helper Properties
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    private var greeting: String {
        switch currentHour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    private var iconColor: Color {
        switch currentHour {
        case 5..<12: return .orange
        case 12..<17: return .yellow
        case 17..<21: return .orange
        default: return .indigo
        }
    }
    
    private var backgroundColors: [Color] {
        Theme.Colors.timeBasedGradient(for: currentHour)
    }
    
    private var hasEntries: Bool {
        !databaseManager.entries.isEmpty
    }
    
    private var entryCount: Int {
        databaseManager.entries.count
    }
    
    private var streakText: String {
        // Calculate streak logic
        "3 days"
    }
    
    private var hasCompletedTutorial: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedTutorial")
    }
    
    // MARK: - Methods
    
    private func startAnimations() {
        // Initialize floating orbs
        floatingOrbs = (0..<5).map { _ in FloatingOrb() }
        
        // Start hero animations
        withAnimation(.easeOut(duration: 0.8)) {
            heroScale = 1.0
            heroOpacity = 1.0
        }
        
        // Start cards animation
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            cardsOffset = 0
            cardsOpacity = 1.0
        }
        
        // Start pulse
        pulseAnimation = true
        
        // Start particle emission
        particleSystem.startEmitting()
    }
    
    private func checkFirstTimeUser() {
        if !hasCompletedTutorial && hasEntries {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showTutorial = true
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct FloatingOrb: Identifiable {
    let id = UUID()
    let size: CGFloat = CGFloat.random(in: 200...400)
    let color: Color = [Color.purple, Color.blue, Color.orange].randomElement()!
    let position: CGPoint = CGPoint(
        x: CGFloat.random(in: -200...1200),
        y: CGFloat.random(in: -200...1000)
    )
    let duration: Double = Double.random(in: 20...40)
    let parallaxFactor: CGFloat = CGFloat.random(in: 0.02...0.08)
}

struct FloatingOrbView: View {
    let orb: FloatingOrb
    let mouseLocation: CGPoint
    @State private var phase: CGFloat = 0
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        orb.color.opacity(0.3),
                        orb.color.opacity(0.1),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: orb.size / 2
                )
            )
            .frame(width: orb.size, height: orb.size)
            .blur(radius: 30)
            .position(orb.position)
            .offset(
                x: sin(phase) * 50,
                y: cos(phase * 0.8) * 30
            )
            .onAppear {
                withAnimation(.linear(duration: orb.duration).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
    }
}

// Continued in next part...