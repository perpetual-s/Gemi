//
//  WelcomeView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/28/25.
//

import SwiftUI

/// Welcome view that introduces users to Gemi's privacy-first approach
struct WelcomeView: View {
    
    // MARK: - Environment
    
    @Environment(AuthenticationManager.self) private var authManager
    
    // MARK: - State
    
    @State private var showSetup = false
    @State private var animateContent = false
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            // Left panel - Branding and description
            leftBrandingPanel
            
            // Right panel - Welcome content and setup
            rightContentPanel
        }
        .background(DesignSystem.Colors.systemBackground)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                animateContent = true
            }
        }
        .sheet(isPresented: $showSetup) {
            AuthenticationSetupView()
        }
    }
    
    // MARK: - View Components
    
    private var leftBrandingPanel: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                // App icon with glow effect
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [DesignSystem.Colors.primary.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(animateContent ? 1.0 : 0.3)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.easeOut(duration: 1.5).delay(0.5), value: animateContent)
                    
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.bounce.up, options: .repeat(1), value: animateContent)
                        .scaleEffect(animateContent ? 1.0 : 0.3)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.spring(response: 1.2, dampingFraction: 0.6).delay(0.8), value: animateContent)
                }
                
                VStack(spacing: 16) {
                    Text("Gemi")
                        .font(.system(size: 56, weight: .ultraLight, design: .default))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.textPrimary, DesignSystem.Colors.textSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(animateContent ? 1 : 0)
                        .offset(x: animateContent ? 0 : -50)
                        .animation(.easeOut(duration: 1.0).delay(1.0), value: animateContent)
                    
                    Text("Your Private AI Diary")
                        .font(.system(size: 20, weight: .light, design: .default))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .opacity(animateContent ? 1 : 0)
                        .offset(x: animateContent ? 0 : -30)
                        .animation(.easeOut(duration: 1.0).delay(1.2), value: animateContent)
                }
                
                // Privacy highlights
                VStack(spacing: 16) {
                    privacyHighlight(icon: "lock.shield.fill", text: "100% Private & Local")
                    privacyHighlight(icon: "cpu.fill", text: "Powered by Gemma 3n AI")
                    privacyHighlight(icon: "heart.fill", text: "Your Thoughts, Your Device")
                }
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 30)
                .animation(.easeOut(duration: 1.0).delay(1.4), value: animateContent)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.primary.opacity(0.02),
                    DesignSystem.Colors.primary.opacity(0.08),
                    DesignSystem.Colors.primary.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DesignSystem.Colors.separator.opacity(0.5))
                .frame(width: 1)
        }
    }
    
    private var rightContentPanel: some View {
        ScrollView {
            VStack(spacing: 48) {
                Spacer(minLength: 60)
                
                // Welcome header
                welcomeHeader
                
                // Privacy features
                privacyFeaturesSection
                
                // AI features
                aiFeaturesSection
                
                // Setup button
                setupButtonSection
                
                Spacer(minLength: 60)
            }
            .padding(.horizontal, 48)
            .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var welcomeHeader: some View {
        VStack(spacing: 20) {
            Text("Welcome to Your")
                .font(.system(size: 32, weight: .thin, design: .default))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : -20)
                .animation(.easeOut(duration: 0.8).delay(1.6), value: animateContent)
            
            Text("Private Sanctuary")
                .font(.system(size: 42, weight: .light, design: .default))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : -20)
                .animation(.easeOut(duration: 0.8).delay(1.8), value: animateContent)
            
            Text("Gemi is a completely private AI diary that runs entirely on your Mac. Your thoughts, conversations, and memories never leave your device.")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(2.0), value: animateContent)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            // App icon
            Image(systemName: "book.closed.fill")
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(DesignSystem.Colors.primary)
                .symbolEffect(.bounce, value: animateContent)
            
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("Welcome to Gemi")
                    .font(DesignSystem.Typography.display)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Your Private AI Diary Companion")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(DesignSystem.Animation.smooth.delay(0.2), value: animateContent)
    }
    
    private var privacyFeaturesSection: some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.success)
                
                Text("Military-Grade Privacy")
                    .font(.system(size: 22, weight: .medium, design: .default))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            .opacity(animateContent ? 1 : 0)
            .offset(x: animateContent ? 0 : -30)
            .animation(.easeOut(duration: 0.8).delay(2.2), value: animateContent)
            
            VStack(spacing: 16) {
                modernPrivacyFeature(
                    icon: "desktopcomputer",
                    title: "100% Local Processing",
                    description: "Every conversation with AI happens on your Mac"
                )
                
                modernPrivacyFeature(
                    icon: "key.horizontal.fill",
                    title: "AES-256 Encryption",
                    description: "Bank-level security for your personal thoughts"
                )
                
                modernPrivacyFeature(
                    icon: "eye.slash.fill",
                    title: "Zero Data Collection",
                    description: "We can't access what we never receive"
                )
            }
        }
    }
    
    private var aiFeaturesSection: some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primary)
                
                Text("Intelligent Companion")
                    .font(.system(size: 22, weight: .medium, design: .default))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            .opacity(animateContent ? 1 : 0)
            .offset(x: animateContent ? 0 : -30)
            .animation(.easeOut(duration: 0.8).delay(2.6), value: animateContent)
            
            VStack(spacing: 16) {
                modernFeatureRow(
                    icon: "message.badge.filled.fill",
                    title: "Natural Conversations",
                    description: "Talk with Gemma 3n AI about your thoughts and feelings"
                )
                
                modernFeatureRow(
                    icon: "memorychip.fill",
                    title: "Contextual Memory",
                    description: "AI remembers your journey for meaningful connections"
                )
                
                modernFeatureRow(
                    icon: "textformat.abc",
                    title: "Beautiful Writing",
                    description: "Elegant, distraction-free writing environment"
                )
            }
        }
    }
    
    private var setupButtonSection: some View {
        VStack(spacing: 20) {
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showSetup = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 18, weight: .medium))
                    
                    Text("Begin Your Journey")
                        .font(.system(size: 18, weight: .semibold, design: .default))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primary,
                            DesignSystem.Colors.primary.opacity(0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .scaleEffect(animateContent ? 1 : 0.8)
            .opacity(animateContent ? 1 : 0)
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(3.0), value: animateContent)
            
            Text("Set up Face ID, Touch ID, or a secure password")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .opacity(animateContent ? 1 : 0)
                .animation(.easeOut(duration: 0.8).delay(3.2), value: animateContent)
        }
        .frame(maxWidth: 360)
    }
    
    // MARK: - Helper Views
    
    private func privacyHighlight(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.success)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            Spacer()
        }
    }
    
    private func modernPrivacyFeature(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.success.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.success)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .opacity(animateContent ? 1 : 0)
        .offset(x: animateContent ? 0 : 20)
        .animation(.easeOut(duration: 0.6).delay(2.4), value: animateContent)
    }
    
    private func modernFeatureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .opacity(animateContent ? 1 : 0)
        .offset(x: animateContent ? 0 : 20)
        .animation(.easeOut(duration: 0.6).delay(2.8), value: animateContent)
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
        .environment(AuthenticationManager())
        .frame(width: 1200, height: 700)
} 