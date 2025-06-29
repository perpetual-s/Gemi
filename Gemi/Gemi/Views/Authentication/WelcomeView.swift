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
        VStack(spacing: 24) {
            // App icon
            Image(systemName: "book.closed.fill")
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: animateContent)
            
            VStack(spacing: 8) {
                Text("Welcome to Gemi")
                    .font(.system(.largeTitle, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text("Your Private AI Diary Companion")
                    .font(.system(.title2, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.8).delay(0.2), value: animateContent)
    }
    
    private var privacySection: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                Text("Complete Privacy")
                    .font(.system(.title2, design: .default, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
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
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.8).delay(0.4), value: animateContent)
    }
    
    private var featuresSection: some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("AI-Powered Journaling")
                    .font(.system(.title2, design: .default, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 20) {
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
        .animation(.easeInOut(duration: 0.8).delay(0.6), value: animateContent)
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                showSetup = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Set Up Secure Access")
                        .font(.system(.body, design: .default, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(.tint)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .scaleEffect(animateContent ? 1 : 0.9)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: animateContent)
            
            Text("Choose Face ID, Touch ID, or a secure password")
                .font(.system(.caption, design: .default))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 300)
    }
    
    // MARK: - Helper Views
    
    private func privacyFeature(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.system(.callout, design: .default))
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.blue.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.system(.callout, design: .default))
                    .foregroundStyle(.secondary)
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