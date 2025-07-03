//
//  TimelineCardView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

/// A beautiful floating card for journal entries in the timeline
struct TimelineCardView: View {
    
    // MARK: - Properties
    
    let entry: JournalEntry
    let isSelected: Bool
    let action: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onExport: () -> Void
    let onShare: () -> Void
    
    @State private var isHovered = false
    @State private var cardOffset: CGFloat = 0
    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.95
    
    @Environment(PerformanceOptimizer.self) private var performanceOptimizer
    @Environment(AccessibilityManager.self) private var accessibilityManager
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Date header
                dateHeader
                
                // Content preview
                contentPreview
                
                // Bottom metadata
                bottomMetadata
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(cardOverlay)
            .scaleEffect(isHovered ? 1.01 : (isSelected ? 1.005 : 1.0))
            .scaleEffect(cardScale)
            .offset(y: isHovered ? -2 : (isSelected ? -1 : 0))
            .offset(y: cardOffset)
            .opacity(cardOpacity)
            .shadow(
                color: Color.black.opacity(isHovered ? 0.08 : 0.04),
                radius: isHovered ? 16 : 8,
                x: 0,
                y: isHovered ? 8 : 4
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.06 : 0.03),
                radius: isHovered ? 32 : 16,
                x: 0,
                y: isHovered ? 16 : 8
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            // Elegant entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                cardOffset = 0
                cardOpacity = 1
                cardScale = 1.0
            }
        }
        .contextMenu {
            JournalEntryContextMenu(
                entry: entry,
                onEdit: onEdit,
                onDelete: onDelete,
                onDuplicate: onDuplicate,
                onExport: onExport,
                onShare: onShare
            )
        }
        .accessibleCard(
            label: String(format: AccessibilityLabels.entryCard, formatDateForAccessibility(entry.date)),
            hint: "Double tap to read entry. Right click for more options.",
            traits: .isButton
        )
        .keyboardNavigatable {
            action()
        }
    }
    
    // MARK: - Date Header
    
    @ViewBuilder
    private var dateHeader: some View {
        HStack(spacing: 12) {
            // Day of week
            Text(entry.createdAt.formatted(.dateTime.weekday(.wide)))
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(Color(red: 0.36, green: 0.61, blue: 0.84))
            
            // Date
            HStack(spacing: 4) {
                Text(entry.createdAt.formatted(.dateTime.day()))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.createdAt.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 11, weight: .medium))
                    
                    Text(entry.createdAt.formatted(.dateTime.year()))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            
            Spacer()
            
            // Time
            Text(entry.createdAt.formatted(.dateTime.hour().minute()))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }
    
    // MARK: - Content Preview
    
    @ViewBuilder
    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            if !entry.title.isEmpty {
                Text(entry.title)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // Content preview with thoughtful truncation
            Text(entry.content)
                .font(.system(size: 16))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(4)
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                .padding(.vertical, 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }
    
    // MARK: - Bottom Metadata
    
    @ViewBuilder
    private var bottomMetadata: some View {
        HStack(spacing: 16) {
            // Word count
            HStack(spacing: 4) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text("\(entry.content.split(separator: " ").count) words")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            // Mood indicator (if available)
            if let mood = entry.mood {
                HStack(spacing: 4) {
                    Image(systemName: moodIcon(for: mood))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(moodColor(for: mood))
                    
                    Text(mood.capitalized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Read more indicator
            if isHovered {
                HStack(spacing: 4) {
                    Text("Read more")
                        .font(.system(size: 13, weight: .medium))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color(red: 0.36, green: 0.61, blue: 0.84))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.98, green: 0.97, blue: 0.96))
                .padding(.bottom, -1)
        )
    }
    
    // MARK: - Card Background
    
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white,
                        Color(red: 0.99, green: 0.99, blue: 0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
    
    // MARK: - Card Overlay
    
    @ViewBuilder
    private var cardOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        isSelected ? Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.3) : Color.clear,
                        isSelected ? Color(red: 0.48, green: 0.70, blue: 0.90).opacity(0.2) : Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isSelected ? 2 : 0
            )
    }
    
    // MARK: - Helper Methods
    
    private func moodIcon(for mood: String) -> String {
        switch mood.lowercased() {
        case "happy": return "sun.max.fill"
        case "sad": return "cloud.rain.fill"
        case "anxious": return "wind"
        case "excited": return "sparkles"
        case "peaceful": return "leaf.fill"
        case "grateful": return "heart.fill"
        default: return "circle.fill"
        }
    }
    
    private func moodColor(for mood: String) -> Color {
        switch mood.lowercased() {
        case "happy": return .orange
        case "sad": return .blue
        case "anxious": return .purple
        case "excited": return .pink
        case "peaceful": return .green
        case "grateful": return .red
        default: return .gray
        }
    }
    
    private func formatDateForAccessibility(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Compact Card Variant

struct CompactTimelineCardView: View {
    let entry: JournalEntry
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Date badge
                VStack(spacing: 2) {
                    Text(entry.createdAt.formatted(.dateTime.day()))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.36, green: 0.61, blue: 0.84))
                    
                    Text(entry.createdAt.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 50)
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    if !entry.title.isEmpty {
                        Text(entry.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    
                    Text(entry.content)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovered ? 1 : 0.5)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color(red: 0.98, green: 0.97, blue: 0.96) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.3) : Color.clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview("Timeline Card") {
    VStack(spacing: 20) {
        TimelineCardView(
            entry: JournalEntry(
                title: "Morning Reflections",
                content: "Today I woke up feeling grateful for the simple things in life. The morning sun streaming through my window, the aroma of freshly brewed coffee, and the peaceful silence before the day begins. These moments remind me to slow down and appreciate the beauty in everyday experiences.",
                mood: "grateful"
            ),
            isSelected: false,
            action: {},
            onEdit: {},
            onDelete: {},
            onDuplicate: {},
            onExport: {},
            onShare: {}
        )
        
        TimelineCardView(
            entry: JournalEntry(
                title: "",
                content: "Quick thought: Sometimes the best ideas come when you're not trying to think of them. Like right now, sitting in the park, watching people go by.",
                mood: "peaceful"
            ),
            isSelected: true,
            action: {},
            onEdit: {},
            onDelete: {},
            onDuplicate: {},
            onExport: {},
            onShare: {}
        )
    }
    .padding(40)
    .frame(width: 600)
    .background(Color(red: 0.96, green: 0.95, blue: 0.94))
}

#Preview("Compact Card") {
    VStack(spacing: 12) {
        CompactTimelineCardView(
            entry: JournalEntry(
                title: "Morning Reflections",
                content: "Today I woke up feeling grateful for the simple things in life."
            ),
            isSelected: false,
            action: {}
        )
        
        CompactTimelineCardView(
            entry: JournalEntry(
                title: "Evening Thoughts",
                content: "The sunset was particularly beautiful today, painting the sky in shades of orange and pink."
            ),
            isSelected: true,
            action: {}
        )
    }
    .padding(40)
    .frame(width: 500)
    .background(Color(red: 0.96, green: 0.95, blue: 0.94))
}