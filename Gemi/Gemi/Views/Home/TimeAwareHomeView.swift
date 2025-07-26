//
//  TimeAwareHomeView.swift
//  Gemi
//
//  Home view wrapper that handles time transitions
//

import SwiftUI

struct TimeAwareHomeView: View {
    @ObservedObject var journalStore: JournalStore
    let onNewEntry: () -> Void
    
    @State private var currentHour = Calendar.current.component(.hour, from: Date())
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Glacier-inspired animated background with dynamic hour
            GlacierBackground(currentHour: currentHour)
                .animation(.easeInOut(duration: 2.0), value: currentHour)
            
            // Home content
            HomeContentView(
                journalStore: journalStore,
                onNewEntry: onNewEntry,
                currentHour: currentHour
            )
        }
        .onAppear {
            updateCurrentHour()
        }
        .onReceive(timer) { _ in
            updateCurrentHour()
        }
    }
    
    private func updateCurrentHour() {
        let newHour = Calendar.current.component(.hour, from: Date())
        if newHour != currentHour {
            withAnimation(.easeInOut(duration: 1.5)) {
                currentHour = newHour
            }
        }
    }
}

// Refactored content view that receives currentHour as parameter
struct HomeContentView: View {
    @ObservedObject var journalStore: JournalStore
    let onNewEntry: () -> Void
    let currentHour: Int
    
    @State private var heroScale: CGFloat = 0.9
    @State private var heroOpacity: Double = 0
    @State private var cardsOffset: CGFloat = 50
    @State private var currentQuote = InspirationQuotes.random()
    @State private var isAnimatingGradient = false
    @State private var hoveredCard: String? = nil
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 40) {
                // Animated time-aware greeting
                AnimatedTimeGreetingFixed(currentHour: currentHour)
                    .padding(.top, 60)
                    .scaleEffect(heroScale)
                    .opacity(heroOpacity)
                
                // Quick actions grid
                quickActionsGrid
                    .padding(.horizontal, 40)
                
                // Privacy promise section
                privacySection
                    .padding(.horizontal, 40)
                
                // Gemma 3n features section
                gemmaFeaturesSection
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
        .scrollIndicators(.never)
        .onAppear {
            animateIn()
        }
    }
    
    // MARK: - Components
    
    private var quickActionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            // New Entry card
            QuickActionCard(
                title: NSLocalizedString("nav.new_entry", comment: "New entry button"),
                subtitle: NSLocalizedString("home.button.new_entry", comment: "Create new entry"),
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
            
            // Beautiful quote display
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
                    
                    Text("Everything stays on your Mac")
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
    
    private var gemmaFeaturesSection: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Powered by Gemma 3n")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Google DeepMind's latest multimodal AI")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Features grid with SF Symbols matching onboarding
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                GemmaFeatureCard(
                    icon: "lock.shield.fill",
                    title: "100% Private",
                    description: "Runs entirely on your Mac",
                    color: .green
                )
                
                GemmaFeatureCard(
                    icon: "photo.on.rectangle.angled",
                    title: "Multimodal AI",
                    description: "Understands text, images, and audio",
                    color: .blue
                )
                
                GemmaFeatureCard(
                    icon: "globe",
                    title: "140+ Languages",
                    description: "Express yourself in any language",
                    color: .orange
                )
                
                GemmaFeatureCard(
                    icon: "hare.fill",
                    title: "Optimized Performance",
                    description: "8GB model, runs like 4GB",
                    color: .purple
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius * 1.5)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.05),
                            Color.purple.opacity(0.02)
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
                                    Color.purple.opacity(0.3),
                                    Color.purple.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.purple.opacity(0.1), radius: 20, x: 0, y: 10)
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