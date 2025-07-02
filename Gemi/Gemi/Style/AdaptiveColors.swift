//
//  AdaptiveColors.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

extension ModernDesignSystem.Colors {
    
    // MARK: - Adaptive Background Colors
    
    static func backgroundPrimary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundPrimaryDark : backgroundPrimary
    }
    
    static func backgroundSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundSecondaryDark : backgroundSecondary
    }
    
    static func backgroundTertiary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundTertiaryDark : backgroundTertiary
    }
    
    static func canvas(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? canvasDark : canvas
    }
    
    // MARK: - Adaptive Text Colors
    
    static func textPrimary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textPrimaryDark : textPrimary
    }
    
    static func textSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textSecondaryDark : textSecondary
    }
    
    static func textTertiary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textTertiaryDark : textTertiary
    }
    
    // MARK: - Adaptive UI Colors
    
    static func divider(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? dividerDark : divider
    }
    
    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? borderDark : border
    }
    
    static func glassBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? glassBackgroundDark : glassBackground
    }
    
    static func glassBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? glassBorderDark : glassBorder
    }
}

// View modifier for adaptive backgrounds
struct AdaptiveBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let lightColor: Color
    let darkColor: Color
    
    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? darkColor : lightColor)
    }
}

extension View {
    func adaptiveBackground(light: Color, dark: Color) -> some View {
        modifier(AdaptiveBackground(lightColor: light, darkColor: dark))
    }
}