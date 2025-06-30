//
//  OnboardingView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(OnboardingState.self) private var onboardingState
    @Environment(\.dismiss) private var dismiss
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            VStack(spacing: 0) {
                // Progress indicator
                progressBar
                    .padding(.top, 20)
                    .padding(.horizontal, 40)
                
                // Content
                Group {
                    switch onboardingState.currentStep {
                    case .welcome:
                        WelcomeStepView()
                    case .privacy:
                        PrivacyStepView()
                    case .setup:
                        SetupStepView()
                    case .ready:
                        ReadyStepView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(DesignSystem.Animation.smooth, value: onboardingState.currentStep)
                
                // Navigation
                navigationButtons
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
        .frame(width: 800, height: 600)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(
            color: Color.black.opacity(0.2),
            radius: 40,
            y: 20
        )
        .scaleEffect(isAnimating ? 1 : 0.9)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(DesignSystem.Animation.smooth) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - Background
    
    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.97, blue: 0.96),
                Color(red: 0.96, green: 0.95, blue: 0.94),
                Color(red: 0.98, green: 0.97, blue: 0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Progress Bar
    
    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                // Progress
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primary,
                                DesignSystem.Colors.secondary
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * onboardingState.currentStep.progress, height: 4)
                    .animation(DesignSystem.Animation.smooth, value: onboardingState.currentStep)
            }
        }
        .frame(height: 4)
    }
    
    // MARK: - Navigation Buttons
    
    @ViewBuilder
    private var navigationButtons: some View {
        HStack {
            // Back button
            if onboardingState.currentStep != .welcome {
                Button {
                    onboardingState.previousStep()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(DesignSystem.Typography.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Skip button (except on last step)
            if onboardingState.currentStep != .ready {
                Button {
                    onboardingState.skipOnboarding()
                } label: {
                    Text("Skip")
                        .font(DesignSystem.Typography.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            // Next/Done button
            Button {
                if onboardingState.currentStep == .ready {
                    onboardingState.completeOnboarding()
                } else {
                    onboardingState.nextStep()
                }
            } label: {
                Text(onboardingState.currentStep == .ready ? "Start Writing" : "Continue")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primary,
                                        DesignSystem.Colors.secondary
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    @State private var illustrationScale: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Illustration
            JournalIllustration(size: 140)
                .scaleEffect(illustrationScale)
                .onAppear {
                    withAnimation(DesignSystem.Animation.playfulBounce.delay(0.2)) {
                        illustrationScale = 1
                    }
                }
            
            // Welcome text
            VStack(spacing: 20) {
                Text("Welcome to Gemi")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.2, blue: 0.3),
                                Color(red: 0.3, green: 0.3, blue: 0.4)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Your thoughts deserve a beautiful home")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                Text("Gemi is your private AI journal that helps you reflect, remember, and understand yourself better—all while keeping your data completely private.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
                    .lineSpacing(6)
            }
            
            Spacer()
            
            // Feature highlights
            HStack(spacing: 40) {
                FeatureHighlight(
                    icon: "lock.shield.fill",
                    title: "100% Private",
                    color: DesignSystem.Colors.success
                )
                
                FeatureHighlight(
                    icon: "sparkles",
                    title: "AI-Powered",
                    color: DesignSystem.Colors.primary
                )
                
                FeatureHighlight(
                    icon: "heart.fill",
                    title: "Made with Care",
                    color: Color.pink
                )
            }
            
            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Privacy Step

struct PrivacyStepView: View {
    @State private var illustrationScale: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Illustration
            PrivacyShieldIllustration(size: 120)
                .scaleEffect(illustrationScale)
                .onAppear {
                    withAnimation(DesignSystem.Animation.playfulBounce.delay(0.2)) {
                        illustrationScale = 1
                    }
                }
            
            // Privacy text
            VStack(spacing: 20) {
                Text("Your Privacy is Sacred")
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Everything stays on your device")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.success)
                
                VStack(alignment: .leading, spacing: 16) {
                    PrivacyPoint(
                        icon: "iphone",
                        text: "All data stored locally on your Mac"
                    )
                    
                    PrivacyPoint(
                        icon: "lock.fill",
                        text: "Encrypted with AES-256-GCM"
                    )
                    
                    PrivacyPoint(
                        icon: "xmark.icloud",
                        text: "No cloud sync, no data mining"
                    )
                    
                    PrivacyPoint(
                        icon: "brain",
                        text: "AI runs entirely offline"
                    )
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignSystem.Colors.success.opacity(0.1))
                )
            }
            .frame(maxWidth: 500)
            
            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Setup Step

struct SetupStepView: View {
    @Environment(OnboardingState.self) private var onboardingState
    @State private var illustrationScale: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Illustration
            AISparkleIllustration(size: 100)
                .scaleEffect(illustrationScale)
                .onAppear {
                    withAnimation(DesignSystem.Animation.playfulBounce.delay(0.2)) {
                        illustrationScale = 1
                    }
                }
            
            // Setup options
            VStack(spacing: 24) {
                Text("Personalize Your Experience")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Choose what works best for you")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                VStack(spacing: 16) {
                    // Biometric authentication
                    SetupOption(
                        icon: "faceid",
                        title: "Use Face ID",
                        description: "Secure your journal with biometric authentication",
                        isEnabled: onboardingState.enableBiometrics
                    ) {
                        onboardingState.enableBiometrics.toggle()
                    }
                    
                    // Auto-save
                    SetupOption(
                        icon: "arrow.clockwise",
                        title: "Auto-save entries",
                        description: "Automatically save your writing every few seconds",
                        isEnabled: onboardingState.enableAutoSave
                    ) {
                        onboardingState.enableAutoSave.toggle()
                    }
                    
                    // Theme selection
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Appearance", systemImage: "paintbrush.fill")
                            .font(DesignSystem.Typography.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                ThemeOption(
                                    theme: theme,
                                    isSelected: onboardingState.selectedTheme == theme
                                ) {
                                    onboardingState.selectedTheme = theme
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.05))
                    )
                }
                .frame(maxWidth: 500)
            }
            
            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Ready Step

struct ReadyStepView: View {
    @State private var illustrationScale: CGFloat = 0
    @State private var confettiTrigger = 0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Illustration
            PencilWritingIllustration(size: 120)
                .scaleEffect(illustrationScale)
                .onAppear {
                    withAnimation(DesignSystem.Animation.playfulBounce.delay(0.2)) {
                        illustrationScale = 1
                    }
                    
                    // Trigger confetti
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        confettiTrigger += 1
                    }
                }
            
            // Ready text
            VStack(spacing: 20) {
                Text("You're All Set! 🎉")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primary,
                                DesignSystem.Colors.secondary
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Your journal is ready and waiting")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                Text("Start with a simple \"Hello\" or share what's on your mind. Gemi will be here to listen, remember, and help you reflect.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
                    .lineSpacing(6)
            }
            
            Spacer()
            
            // Inspiring quote
            VStack(spacing: 12) {
                Text("\"Writing is the painting of the voice\"")
                    .font(DesignSystem.Typography.body)
                    .italic()
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                Text("— Voltaire")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.05))
            )
            
            Spacer()
        }
        .padding(40)
        .confettiCannon(
            counter: $confettiTrigger,
            num: 30,
            colors: [
                DesignSystem.Colors.primary,
                DesignSystem.Colors.secondary,
                DesignSystem.Colors.success,
                Color.pink
            ],
            confettiSize: 10,
            radius: 300
        )
    }
}

// MARK: - Supporting Views

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(color)
            
            Text(title)
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
}

struct PrivacyPoint: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.success)
                .frame(width: 24)
            
            Text(text)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Spacer()
        }
    }
}

struct SetupOption: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isEnabled ? DesignSystem.Colors.primary : .secondary)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Toggle
                ZStack {
                    Capsule()
                        .fill(isEnabled ? DesignSystem.Colors.primary : Color.gray.opacity(0.3))
                        .frame(width: 48, height: 28)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .offset(x: isEnabled ? 11 : -11)
                }
                .animation(DesignSystem.Animation.quick, value: isEnabled)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

struct ThemeOption: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? DesignSystem.Colors.primary : Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: theme.icon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                
                Text(theme.rawValue)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Confetti Effect

struct ConfettiCannon: ViewModifier {
    @State private var confetti: [ConfettiView] = []
    @Binding var counter: Int
    var num: Int
    var colors: [Color]
    var confettiSize: CGFloat
    var radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    ForEach(confetti) { confetti in
                        confetti
                    }
                }
            )
            .onChange(of: counter) { _, _ in
                for _ in 0..<num {
                    confetti.append(
                        ConfettiView(
                            color: colors.randomElement()!,
                            size: confettiSize,
                            radius: radius
                        )
                    )
                }
            }
    }
}

struct ConfettiView: View, Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let radius: CGFloat
    
    @State private var x: CGFloat = 0
    @State private var y: CGFloat = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(x: x, y: y)
            .opacity(opacity)
            .onAppear {
                let angle = Double.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 0...radius)
                
                withAnimation(.easeOut(duration: 2)) {
                    x = cos(angle) * distance
                    y = sin(angle) * distance
                    opacity = 0
                }
            }
    }
}

extension View {
    func confettiCannon(
        counter: Binding<Int>,
        num: Int = 20,
        colors: [Color] = [.red, .green, .blue, .orange, .pink, .purple, .yellow],
        confettiSize: CGFloat = 10,
        radius: CGFloat = 200
    ) -> some View {
        modifier(
            ConfettiCannon(
                counter: counter,
                num: num,
                colors: colors,
                confettiSize: confettiSize,
                radius: radius
            )
        )
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environment(OnboardingState())
}