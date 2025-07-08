//
//  WelcomeCard.swift
//  Gemi
//

import SwiftUI

struct WelcomeCard: View {
    @State private var currentPrompt: String = ""
    @State private var promptOpacity = 0.0
    @State private var illustrationScale = 0.9
    @State private var glowAnimation = false
    let onNewEntry: () -> Void
    @ObservedObject var journalStore: JournalStore
    
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
            case .morning: return [.orange.opacity(0.6), .yellow.opacity(0.4)]
            case .afternoon: return [.blue.opacity(0.5), .cyan.opacity(0.3)]
            case .evening: return [.purple.opacity(0.6), .pink.opacity(0.4)]
            case .night: return [.indigo.opacity(0.7), .purple.opacity(0.5)]
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
        VStack(spacing: 0) {
            // Main content area
            VStack(spacing: 24) {
                // Time-based illustration with glow
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: timeOfDay.colors + [Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                        .opacity(glowAnimation ? 0.8 : 0.5)
                        .animation(
                            .easeInOut(duration: 3)
                            .repeatForever(autoreverses: true),
                            value: glowAnimation
                        )
                    
                    // Icon
                    Image(systemName: timeOfDay.illustration)
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: timeOfDay.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(illustrationScale)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7),
                            value: illustrationScale
                        )
                }
                
                // Greeting
                Text(timeOfDay.greeting)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Writing prompt
                Text(currentPrompt)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .opacity(promptOpacity)
                    .animation(.easeInOut(duration: 0.6), value: promptOpacity)
                    .frame(height: 44)
                
                // Quick actions
                HStack(spacing: 16) {
                    Button(action: onNewEntry) {
                        Label("Write", systemImage: "square.and.pencil")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(Theme.cornerRadius)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 6, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        NotificationCenter.default.post(name: .openChat, object: nil)
                    }) {
                        Label("Chat", systemImage: "message")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(Theme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
            
            // Stats bar
            HStack(spacing: 32) {
                StatItem(
                    icon: "calendar",
                    value: streakDays(),
                    label: "Day Streak"
                )
                
                StatItem(
                    icon: "book.closed",
                    value: totalEntries(),
                    label: "Entries"
                )
                
                StatItem(
                    icon: "star",
                    value: favoriteCount(),
                    label: "Favorites"
                )
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(Color.secondary.opacity(0.05))
        }
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.cornerRadius * 1.5)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius * 1.5)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .onAppear {
            illustrationScale = 1.0
            glowAnimation = true
            updatePrompt()
        }
        .onReceive(timer) { _ in
            updatePrompt()
        }
    }
    
    private func updatePrompt() {
        withAnimation(.easeOut(duration: 0.3)) {
            promptOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentPrompt = promptGenerator.generatePrompt(for: timeOfDay)
            withAnimation(.easeIn(duration: 0.3)) {
                promptOpacity = 1
            }
        }
    }
    
    private func streakDays() -> String {
        // Calculate consecutive days with entries
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today
        
        let sortedEntries = journalStore.entries.sorted { $0.createdAt > $1.createdAt }
        var entryDates = Set(sortedEntries.map { calendar.startOfDay(for: $0.createdAt) })
        
        while entryDates.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        
        return "\(streak)"
    }
    
    private func totalEntries() -> String {
        "\(journalStore.entries.count)"
    }
    
    private func favoriteCount() -> String {
        "\(journalStore.favoriteEntries.count)"
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// Extension to make time-based prompts work
extension WritingPromptGenerator {
    func generatePrompt(for timeOfDay: WelcomeCard.TimeOfDay) -> String {
        switch timeOfDay {
        case .morning:
            return morningPrompts.randomElement() ?? "What's on your mind this morning?"
        case .afternoon:
            return afternoonPrompts.randomElement() ?? "How's your day going?"
        case .evening:
            return eveningPrompts.randomElement() ?? "What was the highlight of your day?"
        case .night:
            return nightPrompts.randomElement() ?? "What thoughts are keeping you up?"
        }
    }
    
    private var morningPrompts: [String] {
        [
            "What are you grateful for this morning?",
            "What's one thing you're looking forward to today?",
            "How did you sleep? Any dreams worth remembering?",
            "What intention will you set for today?",
            "Describe your perfect morning routine.",
            "What's the first thought that came to mind when you woke up?"
        ]
    }
    
    private var afternoonPrompts: [String] {
        [
            "How's your energy level right now?",
            "What's been the best part of your day so far?",
            "Have you taken a moment to breathe today?",
            "What's one small win from this morning?",
            "If you could pause time right now, what would you do?",
            "What's surprising you about today?"
        ]
    }
    
    private var eveningPrompts: [String] {
        [
            "What moment from today do you want to remember?",
            "How did you grow today?",
            "What challenged you today, and how did you handle it?",
            "If today had a color, what would it be and why?",
            "What act of kindness did you witness or perform?",
            "What would you tell your morning self?"
        ]
    }
    
    private var nightPrompts: [String] {
        [
            "What's on your mind as the day winds down?",
            "What are you ready to let go of?",
            "What brought you peace today?",
            "If you could relive one moment from today, which would it be?",
            "What wisdom did today bring you?",
            "How are you feeling in this quiet moment?"
        ]
    }
}