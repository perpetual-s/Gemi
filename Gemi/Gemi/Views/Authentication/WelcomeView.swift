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
        VStack(spacing: 0) {
            // Main content
            ScrollView {
                VStack(spacing: 40) {
                    // Header with app icon and title
                    headerSection
                    
                    // Privacy explanation
                    privacySection
                    
                    // Features overview
                    featuresSection
                    
                    // Get started button
                    actionSection
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 60)
                .frame(maxWidth: 600)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                animateContent = true
            }
        }
        .sheet(isPresented: $showSetup) {
            AuthenticationSetupView()
        }
    }
    
    // MARK: - View Components
    
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
    
    private var privacySection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.success)
                
                Text("Complete Privacy")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                privacyFeature(
                    icon: "desktopcomputer",
                    title: "100% Local Processing",
                    description: "All your thoughts and AI conversations stay on your Mac. Nothing is ever sent to the cloud."
                )
                
                privacyFeature(
                    icon: "key.fill",
                    title: "End-to-End Encryption",
                    description: "Your journal entries are protected with military-grade AES-256 encryption."
                )
                
                privacyFeature(
                    icon: "eye.slash.fill",
                    title: "No Data Collection",
                    description: "We can't see your data because it never leaves your device. Your secrets are truly yours."
                )
            }
        }
        .gemiCardPadding()
        .gemiCard()
        .opacity(animateContent ? 1 : 0)
        .animation(DesignSystem.Animation.smooth.delay(0.4), value: animateContent)
    }
    
    private var featuresSection: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            HStack {
                Image(systemName: "sparkles")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.primary)
                
                Text("AI-Powered Journaling")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                featureRow(
                    icon: "message.fill",
                    title: "Conversational AI",
                    description: "Chat with your diary using local Gemma 3n AI"
                )
                
                featureRow(
                    icon: "brain.head.profile",
                    title: "Contextual Memory",
                    description: "AI remembers your past entries for meaningful conversations"
                )
                
                featureRow(
                    icon: "textformat",
                    title: "Beautiful Writing",
                    description: "Notes.app-inspired editor with rich text support"
                )
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(DesignSystem.Animation.smooth.delay(0.6), value: animateContent)
    }
    
    private var actionSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Button(action: {
                showSetup = true
            }) {
                HStack(spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Set Up Secure Access")
                        .font(DesignSystem.Typography.headline)
                }
            }
            .gemiPrimaryButton()
            .scaleEffect(animateContent ? 1 : 0.9)
            .animation(DesignSystem.Animation.spring.delay(0.8), value: animateContent)
            
            Text("Choose Face ID, Touch ID, or a secure password")
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 300)
    }
    
    // MARK: - Helper Views
    
    private func privacyFeature(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.primary.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
        .environment(AuthenticationManager())
        .frame(width: 800, height: 600)
} 