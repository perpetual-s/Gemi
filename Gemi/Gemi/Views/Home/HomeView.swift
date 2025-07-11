//
//  HomeView.swift
//  Gemi
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var journalStore: JournalStore
    let onNewEntry: () -> Void
    
    @State private var heroScale: CGFloat = 0.9
    @State private var heroOpacity: Double = 0
    @State private var cardsOffset: CGFloat = 50
    @State private var currentQuote = InspirationQuotes.random()
    @State private var isAnimatingGradient = false
    @State private var hoveredCard: String? = nil
    
    let currentHour = Calendar.current.component(.hour, from: Date())
    
    var greeting: String {
        switch currentHour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }
    
    var timeBasedIcon: String {
        switch currentHour {
        case 5..<12: return "sun.max.fill"
        case 12..<17: return "sun.and.horizon.fill"
        case 17..<21: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }
    
    var body: some View {
        ZStack {
            // Dynamic animated background
            animatedBackground
            
            // Floating orbs
            FloatingOrbsView()
            
            // Main content
            ScrollView {
                VStack(spacing: 40) {
                    // Hero section
                    heroSection
                        .padding(.top, 60)
                    
                    // Quick actions grid
                    quickActionsGrid
                        .padding(.horizontal, 40)
                    
                    // Privacy promise section
                    privacySection
                        .padding(.horizontal, 40)
                    
                    // Recent activity
                    if !journalStore.entries.isEmpty {
                        recentActivitySection
                            .padding(.horizontal, 40)
                    }
                    
                    // Inspiration section
                    inspirationSection
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                }
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            animateIn()
        }
    }
    
    // MARK: - Components
    
    private var animatedBackground: some View {
        ZStack {
            // Base gradient
            Theme.Gradients.timeBasedGradient()
                .ignoresSafeArea(.all)
            
            // Animated mesh gradient
            GeometryReader { geometry in
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Theme.Colors.ambientColor(for: currentHour).opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .blur(radius: 40)
                        .offset(
                            x: sin(Date().timeIntervalSince1970 * 0.1 + Double(index)) * 100,
                            y: cos(Date().timeIntervalSince1970 * 0.1 + Double(index)) * 100
                        )
                        .animation(
                            .easeInOut(duration: 10 + Double(index * 2))
                            .repeatForever(autoreverses: true),
                            value: Date()
                        )
                }
            }
            .opacity(0.5)
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 8) {
            // Enhanced time icon with better visibility
            ZStack {
                // Multi-layer glow for depth
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    iconColor.opacity(0.3 - Double(index) * 0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20 + CGFloat(index * 10),
                                endRadius: 80 + CGFloat(index * 20)
                            )
                        )
                        .frame(width: 160 + CGFloat(index * 30), height: 160 + CGFloat(index * 30))
                        .blur(radius: 15 + CGFloat(index * 5))
                }
                
                // Enhanced icon with stronger contrast
                ZStack {
                    // Background circle for contrast
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    iconColor.opacity(0.15),
                                    iconColor.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    // Icon with enhanced visibility
                    Image(systemName: timeBasedIcon)
                        .font(.system(size: 56, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    iconColor,
                                    iconColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: iconColor.opacity(0.5), radius: 10, x: 0, y: 2)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
            }
            .scaleEffect(heroScale)
            .opacity(heroOpacity)
            
            // Greeting with refined typography
            VStack(spacing: 6) {
                Text(greeting)
                    .font(.system(size: 38, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.primary,
                                Color.primary.opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                
                Text("Ready to capture today's moments?")
                    .font(.system(size: 19, weight: .regular, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.secondary,
                                Color.secondary.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .opacity(heroOpacity)
        }
    }
    
    // Computed property for dynamic icon color
    private var iconColor: Color {
        switch currentHour {
        case 5..<12: return Color.orange
        case 12..<17: return Color.yellow
        case 17..<21: return Color.orange
        default: return Color.indigo
        }
    }
    
    private var quickActionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            // New Entry card
            QuickActionCard(
                title: "New Entry",
                subtitle: "Start writing",
                icon: "pencil.and.outline",
                color: .blue,
                isHovered: hoveredCard == "new"
            ) {
                onNewEntry()
            }
            .onHover { hovering in
                hoveredCard = hovering ? "new" : nil
            }
            
            // Chat card
            QuickActionCard(
                title: "Talk to Gemi",
                subtitle: "AI conversation",
                icon: "bubble.left.and.bubble.right.fill",
                color: .purple,
                isHovered: hoveredCard == "chat"
            ) {
                NotificationCenter.default.post(name: .openChat, object: nil)
            }
            .onHover { hovering in
                hoveredCard = hovering ? "chat" : nil
            }
            
            // Memories card
            QuickActionCard(
                title: "Memories",
                subtitle: "View insights",
                icon: "brain",
                color: .pink,
                isHovered: hoveredCard == "memories"
            ) {
                NotificationCenter.default.post(name: .navigateToMemories, object: nil)
            }
            .onHover { hovering in
                hoveredCard = hovering ? "memories" : nil
            }
            
            // Timeline card
            QuickActionCard(
                title: "Timeline",
                subtitle: "Browse entries",
                icon: "calendar",
                color: .orange,
                isHovered: hoveredCard == "timeline"
            ) {
                NotificationCenter.default.post(name: .navigateToTimeline, object: nil)
            }
            .onHover { hovering in
                hoveredCard = hovering ? "timeline" : nil
            }
        }
        .offset(y: cardsOffset)
        .opacity(heroOpacity)
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Entries")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(journalStore.entries.prefix(5)) { entry in
                        RecentEntryCard(entry: entry)
                    }
                }
            }
        }
        .opacity(heroOpacity)
    }
    
    private var inspirationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            HStack {
                Image(systemName: "quote.opening")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Daily Inspiration")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Refresh button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentQuote = InspirationQuotes.random()
                        isAnimatingGradient.toggle()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Get new inspiration")
            }
            
            // Beautiful quote display without traditional box
            ZStack {
                // Animated gradient background
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: isAnimatingGradient ? 
                                [Color.purple.opacity(0.05), Color.pink.opacity(0.03), Color.blue.opacity(0.02)] :
                                [Color.blue.opacity(0.05), Color.purple.opacity(0.03), Color.pink.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimatingGradient)
                
                // Content
                VStack(spacing: 24) {
                    // Large decorative quote mark
                    Text("\"")
                        .font(.system(size: 80, weight: .ultraLight, design: .serif))
                        .foregroundColor(Color.purple.opacity(0.15))
                        .offset(x: -20, y: -10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Quote text with elegant typography
                    Text(currentQuote.text)
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.primary, Color.primary.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .italic()
                        .padding(.horizontal, 40)
                    
                    // Author with decorative elements
                    HStack(spacing: 16) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0), Color.purple.opacity(0.3), Color.purple.opacity(0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 60, height: 1)
                        
                        Text(currentQuote.author)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.secondary, Color.secondary.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.3), Color.purple.opacity(0), Color.purple.opacity(0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 60, height: 1)
                    }
                    
                    // Closing quote mark
                    Text("\"")
                        .font(.system(size: 80, weight: .ultraLight, design: .serif))
                        .foregroundColor(Color.purple.opacity(0.15))
                        .offset(x: 20, y: 10)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 40)
            }
            .shadow(color: Color.purple.opacity(0.1), radius: 30, x: 0, y: 10)
            
            // Writing prompt carousel
            VStack(alignment: .leading, spacing: 16) {
                Text("Or start with a prompt")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(WritingPromptGenerator.shared.getPromptRotation(count: 5), id: \.self) { prompt in
                            PromptCard(prompt: prompt) {
                                // Create new entry with prompt
                                NotificationCenter.default.post(
                                    name: .createEntryWithPrompt,
                                    object: prompt
                                )
                            }
                        }
                    }
                }
            }
        }
        .opacity(heroOpacity)
        .onAppear {
            isAnimatingGradient = true
        }
    }
    
    private var privacySection: some View {
        VStack(spacing: 20) {
            // Header with lock icon
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Privacy, Our Promise")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Powered by Gemma 3n from Google DeepMind")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Privacy features grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                PrivacyFeatureCard(
                    icon: "macbook",
                    title: "100% On-Device",
                    description: "Everything stays on your Mac"
                )
                
                PrivacyFeatureCard(
                    icon: "network.slash",
                    title: "No Cloud Sync",
                    description: "Works completely offline"
                )
                
                PrivacyFeatureCard(
                    icon: "key.fill",
                    title: "Encrypted Storage",
                    description: "Your entries are protected"
                )
                
                PrivacyFeatureCard(
                    icon: "hand.raised.fill",
                    title: "No Data Collection",
                    description: "We can't see your journals"
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius * 1.5)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.05),
                            Color.green.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius * 1.5)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.3),
                                    Color.green.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.green.opacity(0.1), radius: 20, x: 0, y: 10)
        .opacity(heroOpacity)
    }
    
    // MARK: - Methods
    
    private func animateIn() {
        withAnimation(.easeOut(duration: 0.8)) {
            heroScale = 1.0
            heroOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            cardsOffset = 0
        }
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isHovered: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon container
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: color.opacity(0.3), radius: isHovered ? 15 : 8, y: isHovered ? 8 : 4)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isHovered ? 10 : 0))
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                }
                .animation(Theme.delightfulBounce, value: isHovered)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(24)
            .frame(height: 140)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassCard(glowColor: color, glowIntensity: isHovered ? 0.4 : 0.2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(Theme.microInteraction) {
                    isPressed = pressing
                }
            },
            perform: { }
        )
    }
}

// MARK: - Recent Entry Card

struct RecentEntryCard: View {
    let entry: JournalEntry
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(entry.content)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            if let mood = entry.mood {
                HStack {
                    Text(mood.emoji)
                        .font(.system(size: 20))
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .frame(width: 220, height: 140)
        .glassCard()
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(Theme.smoothAnimation, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Floating Orbs

struct FloatingOrbsView: View {
    @State private var positions: [CGPoint] = []
    let orbCount = 5
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<orbCount, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.accentColor.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .offset(
                        x: sin(Date().timeIntervalSince1970 * 0.2 + Double(index)) * 150,
                        y: cos(Date().timeIntervalSince1970 * 0.15 + Double(index)) * 150
                    )
                    .animation(
                        .easeInOut(duration: 20 + Double(index * 3))
                        .repeatForever(autoreverses: true),
                        value: Date()
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Privacy Feature Card

struct PrivacyFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(Theme.microInteraction, value: isHovered)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                .fill(Color.white.opacity(isHovered ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                        .strokeBorder(Color.green.opacity(isHovered ? 0.3 : 0.15), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(Theme.smoothAnimation, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Prompt Card

struct PromptCard: View {
    let prompt: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text(prompt)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 240, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.yellow.opacity(isHovered ? 0.08 : 0.05),
                                Color.orange.opacity(isHovered ? 0.05 : 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.yellow.opacity(isHovered ? 0.3 : 0.1),
                                        Color.orange.opacity(isHovered ? 0.2 : 0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: isHovered ? Color.orange.opacity(0.1) : Color.clear,
                radius: 10,
                x: 0,
                y: 5
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let createEntryWithPrompt = Notification.Name("createEntryWithPrompt")
}

// Note: Other notifications are already defined in MainWindowView