//
//  FilterPanel.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct FilterPanel: View {
    @Binding var selectedMoods: Set<MoodIndicator.Mood>
    @Binding var selectedTags: Set<String>
    @Binding var dateRange: ClosedRange<Date>?
    let availableTags: Set<String>
    
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var useDateRange: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
            // Header
            HStack {
                Text("Filter Entries")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button("Clear All") {
                    clearAllFilters()
                }
                .font(ModernDesignSystem.Typography.callout)
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .buttonStyle(PlainButtonStyle())
            }
            
            Divider()
            
            // Mood filter
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                Text("Mood")
                    .font(ModernDesignSystem.Typography.headline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                FlowLayout(spacing: ModernDesignSystem.Spacing.xs) {
                    ForEach(MoodIndicator.Mood.allCases, id: \.self) { mood in
                        MoodFilterChip(
                            mood: mood,
                            isSelected: selectedMoods.contains(mood),
                            onTap: {
                                toggleMood(mood)
                            }
                        )
                    }
                }
            }
            
            // Tags filter
            if !availableTags.isEmpty {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Tags")
                        .font(ModernDesignSystem.Typography.headline)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    ScrollView {
                        FlowLayout(spacing: ModernDesignSystem.Spacing.xs) {
                            ForEach(Array(availableTags).sorted(), id: \.self) { tag in
                                TagFilterChip(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag),
                                    onTap: {
                                        toggleTag(tag)
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
            
            // Date range filter
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                HStack {
                    Text("Date Range")
                        .font(ModernDesignSystem.Typography.headline)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Toggle("", isOn: $useDateRange)
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                }
                
                if useDateRange {
                    HStack(spacing: ModernDesignSystem.Spacing.md) {
                        DatePicker(
                            "From",
                            selection: $startDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        
                        DatePicker(
                            "To",
                            selection: $endDate,
                            in: startDate...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }
                    .onChange(of: startDate) { _, _ in updateDateRange() }
                    .onChange(of: endDate) { _, _ in updateDateRange() }
                }
            }
            
            Spacer()
            
            // Apply button
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
                
                Button("Apply Filters") {
                    applyFilters()
                    dismiss()
                }
                .modernButton(.primary)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .frame(width: 400, height: 500)
        .background(ModernDesignSystem.Colors.backgroundPrimary)
        .onAppear {
            if let range = dateRange {
                useDateRange = true
                startDate = range.lowerBound
                endDate = range.upperBound
            }
        }
    }
    
    private func toggleMood(_ mood: MoodIndicator.Mood) {
        if selectedMoods.contains(mood) {
            selectedMoods.remove(mood)
        } else {
            selectedMoods.insert(mood)
        }
    }
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func updateDateRange() {
        if useDateRange {
            dateRange = startDate...endDate
        } else {
            dateRange = nil
        }
    }
    
    private func clearAllFilters() {
        selectedMoods.removeAll()
        selectedTags.removeAll()
        dateRange = nil
        useDateRange = false
    }
    
    private func applyFilters() {
        updateDateRange()
    }
}

struct MoodFilterChip: View {
    let mood: MoodIndicator.Mood
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: mood.icon)
                    .font(.system(size: 12))
                Text(mood.rawValue.capitalized)
                    .font(ModernDesignSystem.Typography.caption)
            }
            .foregroundColor(isSelected ? .white : mood.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? mood.color : mood.color.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(mood.color, lineWidth: isSelected ? 0 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TagFilterChip: View {
    let tag: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(tag)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(
                    isSelected ? .white : ModernDesignSystem.Colors.primary
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            isSelected ? ModernDesignSystem.Colors.primary :
                            ModernDesignSystem.Colors.primary.opacity(0.1)
                        )
                        .overlay(
                            Capsule()
                                .stroke(ModernDesignSystem.Colors.primary, lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Flow layout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: result.positions[index].x + bounds.minX,
                    y: result.positions[index].y + bounds.minY
                ),
                proposal: .unspecified
            )
        }
    }
    
    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxX: CGFloat = 0
            
            for subview in subviews {
                let dimensions = subview.dimensions(in: .unspecified)
                
                if currentX + dimensions.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, dimensions.height)
                currentX += dimensions.width + spacing
                maxX = max(maxX, currentX)
            }
            
            self.size = CGSize(width: maxX - spacing, height: currentY + lineHeight)
            self.positions = positions
        }
    }
}