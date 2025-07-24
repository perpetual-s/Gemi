//
//  TimeAwareGreeting.swift
//  Gemi
//
//  Context-aware greeting component for the New Entry header
//

import SwiftUI

struct TimeAwareGreeting: View {
    @State private var greeting: String = ""
    @State private var subtitle: String = ""
    @State private var opacity: Double = 0
    
    private let journalStore: JournalStore?
    
    init(journalStore: JournalStore? = nil) {
        self.journalStore = journalStore
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .opacity(opacity)
        .onAppear {
            updateGreeting()
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1
            }
        }
    }
    
    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let dateString = formatter.string(from: Date())
        
        // Set time-based greeting
        switch hour {
        case 5..<12:
            greeting = "Good morning"
        case 12..<17:
            greeting = "Good afternoon"
        case 17..<21:
            greeting = "Good evening"
        default:
            greeting = "Good night"
        }
        
        // Add personalized subtitle
        subtitle = getPersonalizedSubtitle(hour: hour, dayOfWeek: dayOfWeek, dateString: dateString)
    }
    
    private func getPersonalizedSubtitle(hour: Int, dayOfWeek: Int, dateString: String) -> String {
        // Check writing streak
        if let streak = calculateWritingStreak() {
            if streak > 7 {
                return "Day \(streak) of your writing journey 🔥"
            } else if streak > 3 {
                return "\(streak) days in a row! Keep it up"
            }
        }
        
        // Day-specific messages
        switch dayOfWeek {
        case 2: // Monday
            if hour < 12 {
                return "Ready to start the week?"
            }
        case 6: // Friday
            if hour > 15 {
                return "Time to reflect on the week"
            }
        case 1, 7: // Weekend
            return "Enjoying your weekend?"
        default:
            break
        }
        
        // Default to date
        return dateString
    }
    
    private func calculateWritingStreak() -> Int? {
        guard let store = journalStore else { return nil }
        
        let calendar = Calendar.current
        let sortedEntries = store.entries.sorted { $0.createdAt > $1.createdAt }
        
        guard !sortedEntries.isEmpty else { return nil }
        
        var streak = 1
        var lastDate = calendar.startOfDay(for: sortedEntries[0].createdAt)
        
        for i in 1..<sortedEntries.count {
            let entryDate = calendar.startOfDay(for: sortedEntries[i].createdAt)
            let dayDifference = calendar.dateComponents([.day], from: entryDate, to: lastDate).day ?? 0
            
            if dayDifference == 1 {
                streak += 1
                lastDate = entryDate
            } else if dayDifference > 1 {
                break
            }
        }
        
        // Check if today is part of the streak
        let today = calendar.startOfDay(for: Date())
        let daysSinceLastEntry = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0
        
        if daysSinceLastEntry > 1 {
            return nil // Streak broken
        }
        
        return streak
    }
}

// MARK: - Animated Greeting Transition

struct AnimatedGreetingView: View {
    let text: String
    @State private var isVisible = false
    
    var body: some View {
        Text(text)
            .font(.system(size: 36, weight: .bold, design: .serif))
            .foregroundColor(.primary)
            .scaleEffect(isVisible ? 1 : 0.9)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isVisible = true
                }
            }
    }
}