//
//  TimelineEntryCard.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct TimelineEntryCard: View {
    let entry: JournalEntry
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void
    
    @State private var showActions = false
    @State private var deleteConfirmation = false
    
    // Metadata
    @State private var weather: WeatherData? = nil
    @State private var location: LocationData? = nil
    
    struct WeatherData {
        let condition: String
        let temperature: Int
        let icon: String
    }
    
    struct LocationData {
        let name: String
        let city: String
        let country: String
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content
            cardContent
                .background(cardBackground)
                .onHover { hovering in
                    withAnimation(ModernDesignSystem.Animation.hover) {
                        showActions = hovering
                    }
                }
                .onTapGesture(perform: onTap)
        }
        .confirmationDialog("Delete Entry", isPresented: $deleteConfirmation) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
    }
    
    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with date and actions
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Date and time
                    Text(entry.date.formatted(date: .complete, time: .shortened))
                        .font(ModernDesignSystem.Typography.headline)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    // Metadata row
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        // Mood indicator
                        if let moodString = entry.mood,
                           let mood = MoodIndicator.Mood(rawValue: moodString) {
                            MoodIndicator(mood: mood, size: .small)
                        }
                        
                        // Weather
                        if let weather = weather {
                            HStack(spacing: 4) {
                                Image(systemName: weather.icon)
                                    .font(.system(size: 12))
                                Text("\(weather.temperature)°")
                                    .font(ModernDesignSystem.Typography.caption)
                            }
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                        
                        // Location
                        if let location = location {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                Text(location.city)
                                    .font(ModernDesignSystem.Typography.caption)
                            }
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // Quick actions
                if showActions || isSelected {
                    quickActions
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8)),
                            removal: .opacity
                        ))
                }
            }
            .padding(ModernDesignSystem.Spacing.md)
            
            Divider()
                .opacity(0.1)
            
            // Content preview
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                if !entry.title.isEmpty {
                    Text(entry.title)
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                }
                
                Text(entry.content)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 60)
                    .padding(.vertical, ModernDesignSystem.Spacing.xs)
                
                // Photos preview (if any)
                if hasPhotos {
                    photoPreview
                        .padding(.top, ModernDesignSystem.Spacing.xs)
                }
                
                // Tags preview
                if hasTags {
                    tagsPreview
                        .padding(.top, ModernDesignSystem.Spacing.xs)
                }
            }
            .padding(ModernDesignSystem.Spacing.md)
            
            // Footer with stats
            HStack {
                Label("\(entry.content.split(separator: " ").count) words", systemImage: "text.alignleft")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                
                Spacer()
                
                if let readingTime = calculateReadingTime() {
                    Label("\(readingTime) min read", systemImage: "clock")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .padding(.bottom, ModernDesignSystem.Spacing.sm)
        }
    }
    
    @ViewBuilder
    private var quickActions: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(ModernDesignSystem.Colors.backgroundSecondary)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Edit Entry")
            
            Button {
                onShare()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(ModernDesignSystem.Colors.backgroundSecondary)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Share Entry")
            
            Button {
                deleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(ModernDesignSystem.Colors.error)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(ModernDesignSystem.Colors.error.opacity(0.1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Delete Entry")
        }
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
            .fill(ModernDesignSystem.Colors.backgroundPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                    .stroke(
                        isSelected ? ModernDesignSystem.Colors.primary :
                        isHovered ? ModernDesignSystem.Colors.border :
                        Color.clear,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isHovered ? ModernDesignSystem.Colors.shadowMedium : ModernDesignSystem.Colors.shadow,
                radius: isHovered ? 12 : 8,
                x: 0,
                y: isHovered ? 6 : 4
            )
    }
    
    private var hasPhotos: Bool {
        // TODO: Check for attached photos
        false
    }
    
    private var hasTags: Bool {
        // TODO: Check for tags in content
        entry.content.contains("#")
    }
    
    @ViewBuilder
    private var photoPreview: some View {
        // TODO: Implement photo preview
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                    .fill(ModernDesignSystem.Colors.backgroundTertiary)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                    )
            }
            
            Text("+2 more")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
    }
    
    @ViewBuilder
    private var tagsPreview: some View {
        // Extract tags from content
        let tags = extractTags(from: entry.content)
        
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                    ForEach(tags.prefix(5), id: \.self) { tag in
                        Text(tag)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                            )
                    }
                    
                    if tags.count > 5 {
                        Text("+\(tags.count - 5)")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
    }
    
    private func extractTags(from content: String) -> [String] {
        let pattern = "#[a-zA-Z0-9_]+"
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: content, range: NSRange(content.startIndex..., in: content)) ?? []
        
        return matches.compactMap { match in
            if let range = Range(match.range, in: content) {
                return String(content[range])
            }
            return nil
        }
    }
    
    private func calculateReadingTime() -> Int? {
        let wordsPerMinute = 200.0
        let wordCount = entry.content.split(separator: " ").count
        let minutes = Double(wordCount) / wordsPerMinute
        return minutes > 0.5 ? Int(ceil(minutes)) : nil
    }
}

// Compact version for grid layouts
struct CompactTimelineCard: View {
    let entry: JournalEntry
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            // Date header
            HStack {
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Spacer()
                
                if let moodString = entry.mood,
                   let mood = MoodIndicator.Mood(rawValue: moodString) {
                    Circle()
                        .fill(mood.color)
                        .frame(width: 8, height: 8)
                }
            }
            
            // Title or first line
            Text(entry.title.isEmpty ? entry.content : entry.title)
                .font(ModernDesignSystem.Typography.callout)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Word count
            Text("\(entry.content.split(separator: " ").count) words")
                .font(ModernDesignSystem.Typography.footnote)
                .foregroundColor(ModernDesignSystem.Colors.textTertiary)
        }
        .padding(ModernDesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                .fill(ModernDesignSystem.Colors.backgroundPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                        .stroke(
                            isSelected ? ModernDesignSystem.Colors.primary :
                            isHovered ? ModernDesignSystem.Colors.border :
                            Color.clear,
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(
                    color: isHovered ? ModernDesignSystem.Colors.shadow : Color.clear,
                    radius: isHovered ? 8 : 0,
                    y: isHovered ? 2 : 0
                )
        )
        .onHover { hovering in
            withAnimation(ModernDesignSystem.Animation.hover) {
                isHovered = hovering
            }
        }
        .onTapGesture(perform: onTap)
    }
}