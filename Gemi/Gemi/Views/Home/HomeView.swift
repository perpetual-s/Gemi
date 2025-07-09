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
                .ignoresSafeArea()
            
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
        VStack(spacing: 24) {
            // Time icon with glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Theme.Colors.ambientColor(for: currentHour),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                
                // Icon
                Image(systemName: timeBasedIcon)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Theme.Colors.ambientColor(for: currentHour),
                                Theme.Colors.ambientColor(for: currentHour).opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Theme.Colors.ambientColor(for: currentHour).opacity(0.5), radius: 20)
            }
            .scaleEffect(heroScale)
            .opacity(heroOpacity)
            
            // Greeting
            VStack(spacing: 12) {
                Text(greeting)
                    .font(.system(size: 42, weight: .light, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Ready to capture today's moments?")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .opacity(heroOpacity)
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
        GlassCard {
            VStack(spacing: 16) {
                Text("\"\(currentQuote.text)\"")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .italic()
                
                Text("— \(currentQuote.author)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(32)
        }
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

// MARK: - Notifications are already defined in MainWindowView