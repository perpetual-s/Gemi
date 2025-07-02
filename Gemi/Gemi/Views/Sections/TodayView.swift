//
//  TodayView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct TodayView: View {
    @State private var todayEntry: JournalEntry?
    @State private var isWriting = false
    @State private var writingPrompt = WritingPrompt.random()
    @State private var promptOpacity = 1.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.xl) {
                // Header
                todayHeader
                
                // Writing prompt
                if todayEntry == nil && !isWriting {
                    writingPromptCard
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                }
                
                // Today's entry or compose button
                if let entry = todayEntry {
                    existingEntryCard(entry)
                } else if !isWriting {
                    startWritingSection
                }
                
                // Recent entries preview
                recentEntriesSection
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .frame(maxWidth: ModernDesignSystem.Spacing.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(ModernDesignSystem.Colors.backgroundPrimary)
        .onAppear {
            loadTodayEntry()
            animatePrompt()
        }
    }
    
    // MARK: - Header
    
    private var todayHeader: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            Text(greeting)
                .font(ModernDesignSystem.Typography.display)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text(Date().formatted(date: .complete, time: .omitted))
                .font(ModernDesignSystem.Typography.callout)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }
    
    // MARK: - Writing Prompt
    
    private var writingPromptCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ModernDesignSystem.Colors.moodHappy)
                
                Text("Today's Prompt")
                    .font(ModernDesignSystem.Typography.headline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    refreshPrompt()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(writingPrompt.text)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .lineSpacing(6)
                .opacity(promptOpacity)
            
            if let followUp = writingPrompt.followUp {
                Text(followUp)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .italic()
                    .opacity(promptOpacity)
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                .fill(
                    LinearGradient(
                        colors: [
                            ModernDesignSystem.Colors.moodHappy.opacity(0.05),
                            ModernDesignSystem.Colors.moodHappy.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                        .stroke(ModernDesignSystem.Colors.moodHappy.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(
            color: ModernDesignSystem.Colors.moodHappy.opacity(0.1),
            radius: 12,
            y: 4
        )
    }
    
    // MARK: - Start Writing
    
    private var startWritingSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            Button {
                startWriting()
            } label: {
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start today's entry")
                            .font(ModernDesignSystem.Typography.headline)
                        
                        Text("Capture your thoughts, feelings, and experiences")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16))
                }
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .padding(ModernDesignSystem.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                        .fill(ModernDesignSystem.Colors.backgroundTertiary)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                                .stroke(ModernDesignSystem.Colors.border, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .shadow(
                color: ModernDesignSystem.Components.shadowSM.color,
                radius: ModernDesignSystem.Components.shadowSM.radius,
                y: ModernDesignSystem.Components.shadowSM.y
            )
        }
    }
    
    // MARK: - Existing Entry
    
    private func existingEntryCard(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Label("Today's Entry", systemImage: "checkmark.circle.fill")
                    .font(ModernDesignSystem.Typography.headline)
                    .foregroundColor(ModernDesignSystem.Colors.success)
                
                Spacer()
                
                Button {
                    // TODO: Edit entry
                } label: {
                    Text("Continue writing")
                        .font(ModernDesignSystem.Typography.callout)
                }
                .modernButton(.secondary)
            }
            
            Text(entry.content)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .lineLimit(5)
                .lineSpacing(6)
            
            HStack {
                Label("\(entry.content.split(separator: " ").count) words", systemImage: "text.alignleft")
                
                Spacer()
                
                // TODO: Add mood indicator when mood is implemented in JournalEntry
            }
            .font(ModernDesignSystem.Typography.caption)
            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .cardPadding()
        .modernCard(elevation: .medium)
    }
    
    // MARK: - Recent Entries
    
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Text("Recent Entries")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    // TODO: Navigate to entries
                } label: {
                    Text("View all")
                        .font(ModernDesignSystem.Typography.callout)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                }
                .buttonStyle(.plain)
            }
            
            // Placeholder for recent entries
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(0..<3) { index in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Entry from \(index + 1) days ago")
                                .font(ModernDesignSystem.Typography.callout)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Text("Preview of the journal entry content...")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                    }
                    .padding(ModernDesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                            .fill(ModernDesignSystem.Colors.backgroundSecondary)
                    )
                }
            }
        }
    }
    
    // MARK: - Methods
    
    private func loadTodayEntry() {
        // TODO: Load today's entry from database
    }
    
    private func startWriting() {
        withAnimation(ModernDesignSystem.Animation.spring) {
            isWriting = true
        }
        // TODO: Navigate to compose view
    }
    
    private func refreshPrompt() {
        withAnimation(ModernDesignSystem.Animation.easeOutFast) {
            promptOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            writingPrompt = WritingPrompt.random()
            withAnimation(ModernDesignSystem.Animation.easeOutFast) {
                promptOpacity = 1
            }
        }
    }
    
    private func animatePrompt() {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { @MainActor in
                refreshPrompt()
            }
        }
    }
}

// MARK: - Writing Prompt Model

struct WritingPrompt {
    let text: String
    let followUp: String?
    
    static func random() -> WritingPrompt {
        prompts.randomElement() ?? prompts[0]
    }
    
    static let prompts = [
        WritingPrompt(
            text: "What moment from today would you like to remember?",
            followUp: "It could be something small that made you smile."
        ),
        WritingPrompt(
            text: "How are you feeling right now, in this exact moment?",
            followUp: "Take a deep breath and check in with yourself."
        ),
        WritingPrompt(
            text: "What's one thing you're grateful for today?",
            followUp: "Gratitude can shift your entire perspective."
        ),
        WritingPrompt(
            text: "If today had a color, what would it be and why?",
            followUp: "Sometimes abstract thinking reveals deeper truths."
        ),
        WritingPrompt(
            text: "What challenged you today, and how did you handle it?",
            followUp: "Growth often comes from difficult moments."
        ),
        WritingPrompt(
            text: "Describe someone who made a difference in your day.",
            followUp: "Our connections shape our experiences."
        ),
        WritingPrompt(
            text: "What would you tell your future self about today?",
            followUp: "Imagine reading this entry years from now."
        ),
        WritingPrompt(
            text: "What surprised you today?",
            followUp: "Life's unexpected moments often teach us the most."
        )
    ]
}


// MARK: - Preview

struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TodayView()
        }
        .frame(width: 1000, height: 800)
    }
}