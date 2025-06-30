//
//  AISettingsView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

struct AISettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var tempContextWindow = 4096.0
    @State private var tempMemoryLimit = 50.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // AI Model selection
            SettingsGroup(title: "AI Model") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .purple.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gemma 3n (7.5GB)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                            
                            Text("Running locally via Ollama")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        ModelStatusBadge()
                    }
                    
                    InfoBox(
                        icon: "lock.shield",
                        text: "All AI processing happens on your device. Your conversations never leave your Mac.",
                        color: .purple
                    )
                }
            }
            
            // Response behavior
            SettingsGroup(title: "Response Behavior") {
                VStack(spacing: 16) {
                    PremiumToggle(
                        title: "Stream responses",
                        subtitle: "Show AI responses as they're generated",
                        isOn: $settings.streamResponses
                    )
                    
                    // Context window
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Context window")
                                .font(.system(size: 13, weight: .medium))
                            
                            Spacer()
                            
                            Text("\(Int(tempContextWindow)) tokens")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .foregroundStyle(.secondary)
                        
                        PremiumSlider(
                            value: $tempContextWindow,
                            range: 2048...8192,
                            step: 1024,
                            onEditingChanged: { editing in
                                if !editing {
                                    settings.contextWindow = Int(tempContextWindow)
                                }
                            }
                        )
                        
                        Text("Larger context allows for longer conversations but may be slower")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            // Memory management
            SettingsGroup(title: "Memory System") {
                VStack(spacing: 16) {
                    // Memory limit
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Maximum memories")
                                .font(.system(size: 13, weight: .medium))
                            
                            Spacer()
                            
                            Text("\(Int(tempMemoryLimit))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .foregroundStyle(.secondary)
                        
                        PremiumSlider(
                            value: $tempMemoryLimit,
                            range: 10...100,
                            step: 10,
                            onEditingChanged: { editing in
                                if !editing {
                                    settings.memoryLimit = Int(tempMemoryLimit)
                                }
                            }
                        )
                        
                        Text("Gemi will remember your most important moments within this limit")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    
                    Divider()
                        .opacity(0.1)
                    
                    // Memory stats
                    MemoryStatsView()
                }
            }
            
            // AI personality
            SettingsGroup(title: "Personality") {
                VStack(spacing: 12) {
                    PersonalityOption(
                        title: "Supportive Friend",
                        description: "Warm, encouraging, and empathetic",
                        icon: "heart.fill",
                        isSelected: true
                    )
                    
                    PersonalityOption(
                        title: "Thoughtful Analyst",
                        description: "Insightful, questioning, and reflective",
                        icon: "brain",
                        isSelected: false
                    )
                    
                    PersonalityOption(
                        title: "Creative Muse",
                        description: "Imaginative, inspiring, and artistic",
                        icon: "paintbrush.fill",
                        isSelected: false
                    )
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Model Status Badge

struct ModelStatusBadge: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        .scaleEffect(isAnimating ? 2 : 1)
                        .opacity(isAnimating ? 0 : 1)
                )
            
            Text("Connected")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.1))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.green.opacity(0.2), lineWidth: 0.5)
                )
        )
        .onAppear {
            withAnimation(
                DesignSystem.Animation.breathing
                    .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Memory Stats View

struct MemoryStatsView: View {
    var body: some View {
        HStack(spacing: 20) {
            MemoryStat(
                label: "Current",
                value: "42",
                color: .purple
            )
            
            MemoryStat(
                label: "This Week",
                value: "+8",
                color: .green
            )
            
            MemoryStat(
                label: "Storage",
                value: "2.1 MB",
                color: .blue
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.05),
                            Color.purple.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.purple.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

struct MemoryStat: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Personality Option

struct PersonalityOption: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isSelected ? .white : .purple)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [.purple, .purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.1),
                                    Color.purple.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.purple)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isHovered ?
                    Color.purple.opacity(0.05) :
                    Color.clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected ? Color.purple.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AISettingsView()
        .environment(SettingsStore())
        .padding(40)
        .frame(width: 600)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
}