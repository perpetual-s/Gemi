//
//  GeneralSettingsView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

struct GeneralSettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var tempAutoSaveInterval = 3.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Startup behavior
            SettingsGroup(title: "Startup") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("When Gemi launches")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    ForEach(StartupBehavior.allCases, id: \.self) { behavior in
                        RadioButton(
                            title: behavior.rawValue,
                            isSelected: settings.startupBehavior == behavior
                        ) {
                            withAnimation(DesignSystem.Animation.quick) {
                                settings.startupBehavior = behavior
                            }
                        }
                    }
                }
            }
            
            // Auto-save settings
            SettingsGroup(title: "Auto-save") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Save entries automatically every")
                            .font(.system(size: 13))
                        
                        Text("\(Int(tempAutoSaveInterval))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(minWidth: 20)
                        
                        Text("seconds")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary)
                    
                    PremiumSlider(
                        value: $tempAutoSaveInterval,
                        range: 1...10,
                        step: 1,
                        onEditingChanged: { editing in
                            if !editing {
                                settings.autoSaveInterval = tempAutoSaveInterval
                            }
                        }
                    )
                    
                    Text("Shorter intervals save more frequently but may impact performance")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Sound settings
            SettingsGroup(title: "Sound") {
                PremiumToggle(
                    title: "Enable sound effects",
                    subtitle: "Play subtle sounds for actions like saving",
                    isOn: $settings.enableSounds
                )
            }
            
            Spacer()
        }
    }
}

// MARK: - Settings Group

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            
            content()
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                )
        }
    }
}

// MARK: - Premium Toggle

struct PremiumToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    
    @State private var isPressed = false
    
    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(PremiumToggleStyle())
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(DesignSystem.Animation.quick) {
                        isPressed = pressing
                    }
                }, perform: {})
        }
    }
}

// MARK: - Premium Toggle Style

struct PremiumToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(DesignSystem.Animation.encouragingSpring) {
                configuration.isOn.toggle()
            }
            HapticFeedback.selection()
        } label: {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    configuration.isOn ?
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.61, blue: 0.84),
                            Color(red: 0.42, green: 0.67, blue: 0.88)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.1),
                            Color.primary.opacity(0.08)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 48, height: 28)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .shadow(
                            color: .black.opacity(0.1),
                            radius: 2,
                            x: 0,
                            y: 1
                        )
                        .offset(x: configuration.isOn ? 10 : -10)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Radio Button

struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ?
                            Color(red: 0.36, green: 0.61, blue: 0.84) :
                            Color.primary.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1.5
                        )
                        .frame(width: 18, height: 18)
                    
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.36, green: 0.61, blue: 0.84),
                                        Color(red: 0.42, green: 0.67, blue: 0.88)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 10, height: 10)
                    }
                }
                .scaleEffect(isHovered ? 1.1 : 1.0)
                
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Premium Slider

struct PremiumSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onEditingChanged: (Bool) -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 8)
                
                // Fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.36, green: 0.61, blue: 0.84),
                                Color(red: 0.42, green: 0.67, blue: 0.88)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth(in: geometry.size.width), height: 8)
                
                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .shadow(
                        color: .black.opacity(0.15),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                    .scaleEffect(isDragging ? 1.2 : 1.0)
                    .offset(x: thumbOffset(in: geometry.size.width))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                isDragging = true
                                updateValue(from: gesture.location.x, in: geometry.size.width)
                            }
                            .onEnded { _ in
                                isDragging = false
                                onEditingChanged(false)
                            }
                    )
            }
            .animation(DesignSystem.Animation.quick, value: isDragging)
            .frame(height: 20)
            .contentShape(Rectangle())
            .onTapGesture { location in
                updateValue(from: location.x, in: geometry.size.width)
                onEditingChanged(false)
            }
        }
        .frame(height: 20)
    }
    
    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return totalWidth * percentage
    }
    
    private func thumbOffset(in totalWidth: CGFloat) -> CGFloat {
        fillWidth(in: totalWidth) - 10 // Center the thumb
    }
    
    private func updateValue(from x: CGFloat, in totalWidth: CGFloat) {
        let percentage = max(0, min(1, x / totalWidth))
        let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * percentage
        value = round(newValue / step) * step
        onEditingChanged(true)
    }
}

// MARK: - Preview

#Preview {
    GeneralSettingsView()
        .environment(SettingsStore())
        .padding(40)
        .frame(width: 600)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
}