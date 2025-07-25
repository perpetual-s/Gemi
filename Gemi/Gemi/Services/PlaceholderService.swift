//
//  PlaceholderService.swift
//  Gemi
//
//  Dynamic, context-aware placeholder system for writing
//

import Foundation
import SwiftUI

@MainActor
final class PlaceholderService: ObservableObject {
    static let shared = PlaceholderService()
    
    @Published private(set) var currentPlaceholder: String = ""
    @Published private(set) var isTransitioning: Bool = false
    
    private var placeholderTimer: Timer?
    private var lastEntryDate: Date?
    private var currentIndex: Int = 0
    
    private init() {
        updatePlaceholder()
        startRotation()
    }
    
    // MARK: - Time-based Placeholders
    
    private var timeBasedPlaceholders: [String] {
        let hour = Calendar.current.component(.hour, from: Date())
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        
        switch hour {
        case 5..<12: // Morning
            return [
                "What's on your mind this morning?",
                "How did you sleep?",
                "What are you grateful for today?",
                "Morning thoughts...",
                "What's your intention for today?",
                "How are you feeling as the day begins?",
                isWeekend ? "How's your weekend morning?" : "Ready for the day ahead?"
            ]
            
        case 12..<17: // Afternoon
            return [
                "How's your day going?",
                "Take a moment to reflect...",
                "What's been the highlight so far?",
                "Afternoon musings...",
                "What's on your mind?",
                "How's your energy level?",
                "Pause and reflect..."
            ]
            
        case 17..<21: // Evening
            return [
                "How was your day?",
                "What made you smile today?",
                "Evening reflections...",
                "What went well today?",
                "What challenged you today?",
                "Ready to unwind?",
                "What are you thankful for?"
            ]
            
        default: // Night
            return [
                "Can't sleep? Let's talk...",
                "What's keeping you up?",
                "Tomorrow will be better because...",
                "Night thoughts...",
                "What's on your mind tonight?",
                "Reflect on today...",
                "Dream journal..."
            ]
        }
    }
    
    // MARK: - Context-aware Placeholders
    
    private func getContextualPlaceholder() -> String? {
        // Check for special contexts
        if let lastEntry = lastEntryDate {
            let daysSince = Calendar.current.dateComponents([.day], from: lastEntry, to: Date()).day ?? 0
            
            if daysSince > 7 {
                return "Welcome back! We missed you..."
            } else if daysSince > 3 {
                return "It's been a few days. How have you been?"
            }
        }
        
        // Day-specific prompts
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        switch dayOfWeek {
        case 2: // Monday
            return Bool.random() ? "New week, new possibilities..." : "How's your Monday going?"
        case 6: // Friday
            return Bool.random() ? "Almost weekend! How was your week?" : "Friday reflections..."
        default:
            break
        }
        
        // Month-specific prompts
        let day = Calendar.current.component(.day, from: Date())
        if day == 1 {
            return "New month, fresh start..."
        }
        
        return nil
    }
    
    // MARK: - Weather-based Placeholders
    
    private func getWeatherPlaceholder() -> String? {
        // Reserved for future weather integration
        return nil
    }
    
    // MARK: - Placeholder Management
    
    func updatePlaceholder(animated: Bool = true) {
        // Check for contextual placeholder first
        if let contextual = getContextualPlaceholder() {
            setPlaceholder(contextual, animated: animated)
            return
        }
        
        // Use time-based placeholder
        let placeholders = timeBasedPlaceholders
        if !placeholders.isEmpty {
            currentIndex = (currentIndex + 1) % placeholders.count
            setPlaceholder(placeholders[currentIndex], animated: animated)
        }
    }
    
    private func setPlaceholder(_ text: String, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                isTransitioning = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.currentPlaceholder = text
                withAnimation(.easeIn(duration: 0.3)) {
                    self.isTransitioning = false
                }
            }
        } else {
            currentPlaceholder = text
        }
    }
    
    // MARK: - Timer Management
    
    private func startRotation() {
        placeholderTimer?.invalidate()
        placeholderTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            Task { @MainActor in
                self.updatePlaceholder()
            }
        }
    }
    
    func stopRotation() {
        placeholderTimer?.invalidate()
        placeholderTimer = nil
    }
    
    // MARK: - Entry Tracking
    
    func recordEntry() {
        lastEntryDate = Date()
    }
    
    // MARK: - Special Placeholders
    
    func getContinuationPlaceholder(for previousContent: String) -> String {
        // Extract topic from previous content
        let words = previousContent.split(separator: " ").prefix(20)
        if words.count > 10 {
            return "Let's continue where you left off..."
        }
        return "Continue your thought..."
    }
}

// MARK: - SwiftUI View

struct DynamicPlaceholder: View {
    @StateObject private var placeholderService = PlaceholderService.shared
    
    var body: some View {
        Text(placeholderService.currentPlaceholder)
            .font(.system(size: 17, weight: .regular))
            .foregroundColor(.secondary.opacity(0.5))
            .opacity(placeholderService.isTransitioning ? 0 : 1)
            .animation(.easeInOut(duration: 0.3), value: placeholderService.isTransitioning)
    }
}