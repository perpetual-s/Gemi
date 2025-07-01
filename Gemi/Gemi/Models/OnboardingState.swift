//
//  OnboardingState.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI
import Observation

@Observable
final class OnboardingState {
    // MARK: - Properties
    
    var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
    var currentStep: OnboardingStep = .welcome
    var hasSeenCoachMarks: Set<CoachMarkType> = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(hasSeenCoachMarks.map { $0.rawValue }) {
                UserDefaults.standard.set(encoded, forKey: "seenCoachMarks")
            }
        }
    }
    
    // Privacy settings chosen during onboarding
    var enableBiometrics: Bool = false
    var enableAutoSave: Bool = true
    var selectedTheme: Gemi.AppTheme = .system
    
    // MARK: - Initialization
    
    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // Load seen coach marks
        if let data = UserDefaults.standard.data(forKey: "seenCoachMarks"),
           let marks = try? JSONDecoder().decode([String].self, from: data) {
            self.hasSeenCoachMarks = Set(marks.compactMap { CoachMarkType(rawValue: $0) })
        }
    }
    
    // MARK: - Methods
    
    func nextStep() {
        guard let nextStep = currentStep.next else {
            completeOnboarding()
            return
        }
        withAnimation(DesignSystem.Animation.smooth) {
            currentStep = nextStep
        }
    }
    
    func previousStep() {
        guard let previousStep = currentStep.previous else { return }
        withAnimation(DesignSystem.Animation.smooth) {
            currentStep = previousStep
        }
    }
    
    func skipOnboarding() {
        completeOnboarding()
    }
    
    func completeOnboarding() {
        withAnimation(DesignSystem.Animation.smooth) {
            hasCompletedOnboarding = true
        }
    }
    
    func markCoachMarkAsSeen(_ type: CoachMarkType) {
        hasSeenCoachMarks.insert(type)
    }
    
    func shouldShowCoachMark(_ type: CoachMarkType) -> Bool {
        !hasSeenCoachMarks.contains(type)
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        currentStep = .welcome
        hasSeenCoachMarks.removeAll()
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "seenCoachMarks")
    }
}

// MARK: - Onboarding Steps

enum OnboardingStep: CaseIterable {
    case welcome
    case privacy
    case setup
    case ready
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Gemi"
        case .privacy:
            return "Your Privacy Matters"
        case .setup:
            return "Personalize Your Experience"
        case .ready:
            return "You're All Set!"
        }
    }
    
    var subtitle: String {
        switch self {
        case .welcome:
            return "Your private AI journal companion"
        case .privacy:
            return "Everything stays on your device"
        case .setup:
            return "Make Gemi work best for you"
        case .ready:
            return "Let's start your journaling journey"
        }
    }
    
    var next: OnboardingStep? {
        switch self {
        case .welcome: return .privacy
        case .privacy: return .setup
        case .setup: return .ready
        case .ready: return nil
        }
    }
    
    var previous: OnboardingStep? {
        switch self {
        case .welcome: return nil
        case .privacy: return .welcome
        case .setup: return .privacy
        case .ready: return .setup
        }
    }
    
    var progress: Double {
        switch self {
        case .welcome: return 0.25
        case .privacy: return 0.5
        case .setup: return 0.75
        case .ready: return 1.0
        }
    }
}

// MARK: - Coach Mark Types

enum CoachMarkType: String, Codable {
    case firstEntry = "first_entry"
    case aiChat = "ai_chat"
    case memories = "memories"
    case insights = "insights"
    case search = "search"
    case export = "export"
    case themes = "themes"
}

