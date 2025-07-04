//
//  AppearanceSettingsView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var previewText = "The quick brown fox jumps over the lazy dog"
    
    var body: some View {
        @Bindable var settings = settingsStore
        
        VStack(alignment: .leading, spacing: 24) {
            // Theme selection
            SettingsGroup(title: "Theme") {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            ThemeCard(
                                theme: theme,
                                isSelected: settings.theme == theme
                            ) {
                                withAnimation(DesignSystem.Animation.smooth) {
                                    settings.theme = theme
                                }
                            }
                        }
                    }
                    
                    Text("Gemi will match your system appearance when set to System")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Accent color
            SettingsGroup(title: "Accent Color") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(AppAccentColor.allCases, id: \.self) { color in
                            ColorButton(
                                accentColor: color,
                                isSelected: settings.accentColor == color
                            ) {
                                withAnimation(DesignSystem.Animation.quick) {
                                    settings.accentColor = color
                                }
                            }
                        }
                    }
                    
                    Text("Choose a color that matches your style")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Font settings
            SettingsGroup(title: "Typography") {
                VStack(alignment: .leading, spacing: 16) {
                    // Font size selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Editor font size")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(FontSize.allCases, id: \.self) { size in
                                FontSizeButton(
                                    fontSize: size,
                                    isSelected: settings.fontSize == size
                                ) {
                                    withAnimation(DesignSystem.Animation.quick) {
                                        settings.fontSize = size
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                        .opacity(0.1)
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text(previewText)
                            .font(.system(size: fontSizeValue(settings.fontSize)))
                            .foregroundStyle(.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.03))
                            )
                    }
                    
                    // Additional options
                    PremiumToggle(
                        title: "Show line numbers",
                        subtitle: "Display line numbers in the editor",
                        isOn: $settings.showLineNumbers
                    )
                }
            }
            
            Spacer()
        }
    }
    
    private func fontSizeValue(_ size: FontSize) -> CGFloat {
        switch size {
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        }
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(previewBackground)
                        .frame(height: 80)
                    
                    VStack(spacing: 4) {
                        // Mock UI elements
                        RoundedRectangle(cornerRadius: 4)
                            .fill(previewForeground.opacity(0.8))
                            .frame(width: 60, height: 6)
                        
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(previewAccent)
                                .frame(width: 20, height: 20)
                            
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(previewForeground.opacity(0.6))
                                    .frame(width: 30, height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(previewForeground.opacity(0.4))
                                    .frame(width: 25, height: 4)
                            }
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                
                Text(theme.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var previewBackground: Color {
        switch theme {
        case .system:
            return colorScheme == .dark ? Color.black : Color.white
        case .light:
            return Color.white
        case .dark:
            return Color.black
        }
    }
    
    private var previewForeground: Color {
        switch theme {
        case .system:
            return colorScheme == .dark ? Color.white : Color.black
        case .light:
            return Color.black
        case .dark:
            return Color.white
        }
    }
    
    private var previewAccent: Color {
        Color(red: 0.36, green: 0.61, blue: 0.84)
    }
}

// MARK: - Color Button

struct ColorButton: View {
    let accentColor: AppAccentColor
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.gradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .opacity(isSelected ? 1 : 0)
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            Color.primary.opacity(0.2),
                            lineWidth: 1
                        )
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .shadow(
                    color: color.opacity(isHovered ? 0.4 : 0),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovered = hovering
            }
        }
    }
    
    private var color: Color {
        switch accentColor {
        case .blue:
            return Color(red: 0.36, green: 0.61, blue: 0.84)
        case .purple:
            return Color(red: 0.58, green: 0.42, blue: 0.84)
        case .green:
            return Color(red: 0.36, green: 0.75, blue: 0.45)
        case .orange:
            return Color(red: 0.95, green: 0.61, blue: 0.28)
        }
    }
}

// MARK: - Font Size Button

struct FontSizeButton: View {
    let fontSize: FontSize
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("Aa")
                    .font(.system(size: sampleSize))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 60, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                isSelected ?
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
                                        isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.05),
                                        isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                
                Text(fontSize.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovered = hovering
            }
        }
    }
    
    private var sampleSize: CGFloat {
        switch fontSize {
        case .small: return 14
        case .medium: return 18
        case .large: return 22
        }
    }
}

// MARK: - Preview

#Preview {
    AppearanceSettingsView()
        .environment(SettingsStore())
        .padding(40)
        .frame(width: 600)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
}