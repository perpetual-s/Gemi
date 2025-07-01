//
//  AccessibilityManager.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

/// Manages accessibility features for Gemi
@Observable
final class AccessibilityManager {
    
    // MARK: - Properties
    
    /// Tracks if VoiceOver is running
    private(set) var isVoiceOverRunning = false
    
    /// Tracks if Reduce Motion is enabled
    private(set) var reduceMotionEnabled = false
    
    /// Tracks if Increase Contrast is enabled
    private(set) var increaseContrastEnabled = false
    
    /// Current accessibility font size
    private(set) var accessibilityFontSize: DynamicTypeSize = .medium
    
    // MARK: - Initialization
    
    init() {
        observeAccessibilityChanges()
    }
    
    // MARK: - Accessibility Monitoring
    
    private func observeAccessibilityChanges() {
        // Monitor VoiceOver
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: NSNotification.Name(rawValue: "NSAccessibilityVoiceOverStatusChanged"),
            object: nil
        )
        
        // Check initial states
        updateAccessibilityStates()
    }
    
    @objc private func voiceOverStatusChanged() {
        updateAccessibilityStates()
    }
    
    private func updateAccessibilityStates() {
        isVoiceOverRunning = NSWorkspace.shared.isVoiceOverEnabled
        reduceMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        increaseContrastEnabled = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }
}

// MARK: - Accessibility View Modifiers

struct AccessibleCard: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityRespondsToUserInteraction(true)
    }
}

struct AccessibleButton: ViewModifier {
    let label: String
    let hint: String?
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityRespondsToUserInteraction(true)
    }
}

struct AccessibleTextEditor: ViewModifier {
    let label: String
    let value: String
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityAddTraits([.isSearchField, .allowsDirectInteraction])
            .accessibilityRespondsToUserInteraction(true)
    }
}

// MARK: - VoiceOver Announcements

struct VoiceOverAnnouncer {
    @MainActor
    static func announce(_ message: String) {
        if let window = NSApp.mainWindow {
            NSAccessibility.post(
                element: window,
                notification: .announcementRequested,
                userInfo: [
                    NSAccessibility.NotificationUserInfoKey.announcement: message
                ]
            )
        }
    }
}

// MARK: - High Contrast Colors

struct HighContrastColors {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AccessibilityManager.self) private var accessibility
    
    var primaryText: Color {
        if accessibility.increaseContrastEnabled {
            return colorScheme == .dark ? .white : .black
        }
        return DesignSystem.Colors.textPrimary
    }
    
    var secondaryText: Color {
        if accessibility.increaseContrastEnabled {
            return colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8)
        }
        return DesignSystem.Colors.textSecondary
    }
    
    var background: Color {
        if accessibility.increaseContrastEnabled {
            return colorScheme == .dark ? .black : .white
        }
        return DesignSystem.Colors.systemBackground
    }
    
    var cardBackground: Color {
        if accessibility.increaseContrastEnabled {
            return colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
        }
        return DesignSystem.Colors.floatingPanelBackground
    }
}

// MARK: - Keyboard Navigation Support

struct KeyboardNavigatable: ViewModifier {
    @FocusState private var isFocused: Bool
    let onActivate: () -> Void
    
    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            .onKeyPress(.space) {
                onActivate()
                return .handled
            }
            .onKeyPress(.return) {
                onActivate()
                return .handled
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DesignSystem.Colors.primary, lineWidth: 2)
                    .opacity(isFocused ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            )
    }
}

// MARK: - Dynamic Type Support

struct DynamicTypeModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

// MARK: - View Extensions

extension View {
    func accessibleCard(label: String, hint: String? = nil, traits: AccessibilityTraits = []) -> some View {
        self.modifier(AccessibleCard(label: label, hint: hint, traits: traits))
    }
    
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self.modifier(AccessibleButton(label: label, hint: hint))
    }
    
    func accessibleTextEditor(label: String, value: String) -> some View {
        self.modifier(AccessibleTextEditor(label: label, value: value))
    }
    
    func keyboardNavigatable(onActivate: @escaping () -> Void) -> some View {
        self.modifier(KeyboardNavigatable(onActivate: onActivate))
    }
    
    func supportsDynamicType() -> some View {
        self.modifier(DynamicTypeModifier())
    }
}

// MARK: - Accessibility Labels

struct AccessibilityLabels {
    // Timeline
    static let timelineTitle = "Journal entries timeline"
    static let newEntryButton = "Create new journal entry"
    static let entryCard = "Journal entry from %@"
    static let deleteEntryButton = "Delete this journal entry"
    
    // Editor
    static let editorTitle = "Journal entry editor"
    static let editorTextArea = "Write your journal entry here"
    static let saveButton = "Save journal entry"
    static let cancelButton = "Cancel editing"
    
    // AI Chat
    static let chatTitle = "Chat with Gemi"
    static let chatInput = "Type your message to Gemi"
    static let sendButton = "Send message"
    static let clearChatButton = "Clear chat history"
    
    // Settings
    static let settingsTitle = "Application settings"
    static let privacySection = "Privacy and security settings"
    static let appearanceSection = "Appearance settings"
    static let aiSection = "AI model settings"
    
    // Authentication
    static let loginTitle = "Login to Gemi"
    static let passwordField = "Enter your password"
    static let biometricButton = "Authenticate with Touch ID or Face ID"
}