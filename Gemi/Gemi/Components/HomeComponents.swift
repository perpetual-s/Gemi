//
//  HomeComponents.swift
//  Gemi
//
//  Reusable components for the Home view
//

import SwiftUI

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isHovered: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon container
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: color.opacity(0.3), radius: isHovered ? 15 : 8, y: isHovered ? 8 : 4)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isHovered ? 10 : 0))
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                }
                .animation(Theme.delightfulBounce, value: isHovered)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(24)
            .frame(height: 140)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassCard(glowColor: color, glowIntensity: isHovered ? 0.4 : 0.2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(Theme.microInteraction) {
                    isPressed = pressing
                }
            },
            perform: { }
        )
    }
}

// MARK: - Recent Entry Card

struct RecentEntryCard: View {
    let entry: JournalEntry
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(entry.content)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            if let mood = entry.mood {
                HStack {
                    Text(mood.emoji)
                        .font(.system(size: 20))
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .frame(width: 220, height: 140)
        .glassCard()
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(Theme.smoothAnimation, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Privacy Feature Card

struct PrivacyFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(Theme.microInteraction, value: isHovered)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: 100)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                .fill(Color.white.opacity(isHovered ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                        .strokeBorder(Color.green.opacity(isHovered ? 0.3 : 0.15), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(Theme.smoothAnimation, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Gemma Feature Card

struct GemmaFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @State private var isHovered = false
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // SF Symbol with elegant animation
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isHovered ? 1.15 : 1.0)
                .rotationEffect(.degrees(isHovered ? 5 : 0))
                .shadow(color: color.opacity(isHovered ? 0.3 : 0), radius: 8)
                .animation(Theme.smoothAnimation, value: isHovered)
                .animation(
                    Animation.easeInOut(duration: 3).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: 100)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                .fill(color.opacity(isHovered ? 0.12 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                        .strokeBorder(color.opacity(isHovered ? 0.4 : 0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: isHovered ? color.opacity(0.2) : Color.clear, radius: 8, y: 4)
        .animation(Theme.smoothAnimation, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            // Slight delay for each card animation
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0...0.5)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Prompt Card

struct PromptCard: View {
    let prompt: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text(prompt)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 240, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.yellow.opacity(isHovered ? 0.08 : 0.05),
                                Color.orange.opacity(isHovered ? 0.05 : 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.yellow.opacity(isHovered ? 0.3 : 0.1),
                                        Color.orange.opacity(isHovered ? 0.2 : 0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: isHovered ? Color.orange.opacity(0.1) : Color.clear,
                radius: 10,
                x: 0,
                y: 5
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let createEntryWithPrompt = Notification.Name("createEntryWithPrompt")
}