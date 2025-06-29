//
//  DesignSystem.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/29/25.
//

import SwiftUI

/// Gemi's comprehensive design system for creating a beautiful, Notes.app-inspired interface.
/// This follows the specifications outlined in the PRD for calm, focused, and elegantly functional design.
enum DesignSystem {
    
    // MARK: - Typography Scale
    
    enum Typography {
        /// Large display text for major headings (40pt)
        static let display = Font.custom("SF Pro Display", size: 40, relativeTo: .largeTitle)
            .weight(.bold)
        
        /// Primary headings (28pt)
        static let title1 = Font.custom("SF Pro Display", size: 28, relativeTo: .title)
            .weight(.bold)
        
        /// Secondary headings (22pt)
        static let title2 = Font.custom("SF Pro Display", size: 22, relativeTo: .title2)
            .weight(.semibold)
        
        /// Section headings (20pt)
        static let title3 = Font.custom("SF Pro Text", size: 20, relativeTo: .title3)
            .weight(.semibold)
        
        /// Emphasized body text (17pt)
        static let headline = Font.custom("SF Pro Text", size: 17, relativeTo: .headline)
            .weight(.semibold)
        
        /// Primary body text (17pt)
        static let body = Font.custom("SF Pro Text", size: 17, relativeTo: .body)
        
        /// Secondary body text (15pt)
        static let callout = Font.custom("SF Pro Text", size: 15, relativeTo: .callout)
        
        /// Tertiary text (13pt)
        static let subheadline = Font.custom("SF Pro Text", size: 13, relativeTo: .subheadline)
        
        /// Small text (12pt)
        static let footnote = Font.custom("SF Pro Text", size: 12, relativeTo: .footnote)
        
        /// Captions and labels (11pt)
        static let caption1 = Font.custom("SF Pro Text", size: 11, relativeTo: .caption)
        
        /// Smallest text (10pt)
        static let caption2 = Font.custom("SF Pro Text", size: 10, relativeTo: .caption2)
        
        /// Monospaced for technical elements
        static let mono = Font.custom("SF Mono", size: 13, relativeTo: .body)
    }
    
    /// Alias for Typography to maintain compatibility
    typealias Fonts = Typography
    
    // MARK: - Sophisticated Color Palette
    
    enum Colors {
        // MARK: Brand Colors
        
        /// Primary brand color - sophisticated blue
        static let primary = Color.accentColor
        
        /// Secondary brand accent
        static let secondary = Color.blue.opacity(0.8)
        
        /// Brand color alias
        static let brand = primary
        
        /// Background color alias
        static let background = backgroundPrimary
        
        /// Success states - calming green
        static let success = Color.green
        
        /// Warning states - warm orange
        static let warning = Color.orange
        
        /// Error states - gentle red
        static let error = Color.red
        
        // MARK: Text Colors
        
        /// Primary text - high contrast
        static let textPrimary = Color.primary
        
        /// Secondary text - medium contrast
        static let textSecondary = Color.secondary
        
        /// Tertiary text - low contrast
        static let textTertiary = Color(NSColor.tertiaryLabelColor)
        
        /// Placeholder text
        static let textPlaceholder = Color(NSColor.placeholderTextColor)
        
        // MARK: Background Colors
        
        /// Primary background
        static let backgroundPrimary = Color(NSColor.windowBackgroundColor)
        
        /// Secondary background - cards and panels
        static let backgroundSecondary = Color(NSColor.controlBackgroundColor)
        
        /// Tertiary background - subtle elevation
        static let backgroundTertiary = Color(NSColor.tertiarySystemFill)
        
        /// Window background
        static let backgroundWindow = Color(NSColor.windowBackgroundColor)
        
        // MARK: Interface Colors
        
        /// Dividers and borders
        static let divider = Color(NSColor.separatorColor)
        
        /// Interactive elements
        static let interactive = Color.accentColor
        
        /// Hover states
        static let hover = Color(NSColor.controlAccentColor).opacity(0.1)
        
        /// Selection states
        static let selection = Color(NSColor.selectedContentBackgroundColor)
        
        // MARK: Semantic Colors (fallback to system)
        
        static let systemBackground = Color(NSColor.windowBackgroundColor)
        static let systemSecondaryBackground = Color(NSColor.controlBackgroundColor)
        static let systemTertiaryBackground = Color(NSColor.tertiarySystemFill)
        static let systemAccent = Color.accentColor
    }
    
    // MARK: - Spacing System
    
    enum Spacing {
        /// Micro spacing (2pt) - very tight elements
        static let micro: CGFloat = 2
        
        /// Tiny spacing (4pt) - tight elements
        static let tiny: CGFloat = 4
        
        /// Small spacing (8pt) - close related elements
        static let small: CGFloat = 8
        
        /// Medium spacing (12pt) - related elements
        static let medium: CGFloat = 12
        
        /// Base spacing (16pt) - standard margin
        static let base: CGFloat = 16
        
        /// Large spacing (24pt) - section spacing
        static let large: CGFloat = 24
        
        /// Extra large spacing (32pt) - major sections
        static let extraLarge: CGFloat = 32
        
        /// Huge spacing (48pt) - page level spacing
        static let huge: CGFloat = 48
        
        // MARK: Layout Constants
        
        /// Sidebar width (240pt) - as specified in PRD
        static let sidebarWidth: CGFloat = 240
        
        /// Timeline width (320pt) - optimal for entry cards
        static let timelineWidth: CGFloat = 320
        
        /// Minimum timeline width (300pt)
        static let timelineMinWidth: CGFloat = 300
        
        /// Maximum timeline width (400pt)
        static let timelineMaxWidth: CGFloat = 400
        
        // MARK: Semantic Spacing
        
        /// Standard margin spacing (16pt)
        static let margin: CGFloat = base
        
        /// Internal padding for components (12pt)
        static let internalPadding: CGFloat = medium
    }
    
    // MARK: - Component Specifications
    
    enum Components {
        // MARK: Corner Radius
        
        /// Small radius for buttons and small elements
        static let radiusSmall: CGFloat = 6
        
        /// Medium radius for cards and panels
        static let radiusMedium: CGFloat = 12
        
        /// Large radius for major containers
        static let radiusLarge: CGFloat = 16
        
        /// Base corner radius alias
        static let radiusBase: CGFloat = radiusMedium
        
        /// Corner radius alias
        static let cornerRadius: CGFloat = radiusMedium
        
        // MARK: Shadows
        
        /// Subtle shadow for cards
        static let shadowCard = (color: Color.black.opacity(0.08), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(2))
        
        /// Elevated shadow for modals
        static let shadowElevated = (color: Color.black.opacity(0.12), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(4))
        
        /// Deep shadow for overlays
        static let shadowDeep = (color: Color.black.opacity(0.16), radius: CGFloat(24), x: CGFloat(0), y: CGFloat(8))
        
        // MARK: Sizing
        
        /// Standard button height
        static let buttonHeight: CGFloat = 36
        
        /// Large button height
        static let buttonHeightLarge: CGFloat = 44
        
        /// Toolbar height
        static let toolbarHeight: CGFloat = 52
        
        /// Minimum touch target
        static let touchTarget: CGFloat = 44
    }
    
    // MARK: - Animation Specifications
    
    enum Animation {
        /// Quick interactions (0.15s)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        
        /// Standard animations (0.25s)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        
        /// Smooth transitions (0.35s)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.35)
        
        /// Spring animation for interactive elements
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        
        /// Gentle spring for subtle movements
        static let gentleSpring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.9)
    }
}

// MARK: - Button Styles

/// Primary button style with Gemi's signature look
struct GemiPrimaryButtonStyle: ButtonStyle {
    let isLoading: Bool
    
    init(isLoading: Bool = false) {
        self.isLoading = isLoading
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundStyle(.white)
            .frame(height: DesignSystem.Components.buttonHeight)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                    .fill(DesignSystem.Colors.primary)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(isLoading ? 0.6 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
            .disabled(isLoading)
    }
}

/// Secondary button style
struct GemiSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundStyle(DesignSystem.Colors.primary)
            .frame(height: DesignSystem.Components.buttonHeight)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                    .stroke(DesignSystem.Colors.primary, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                            .fill(configuration.isPressed ? DesignSystem.Colors.primary.opacity(0.1) : Color.clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

/// Subtle button style for less prominent actions
struct GemiSubtleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.callout)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                    .fill(configuration.isPressed ? DesignSystem.Colors.hover : DesignSystem.Colors.backgroundSecondary)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Card Styles

/// Standard card background modifier
struct GemiCardStyle: ViewModifier {
    let showShadow: Bool
    
    init(showShadow: Bool = true) {
        self.showShadow = showShadow
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                    .fill(DesignSystem.Colors.backgroundSecondary)
                    .shadow(
                        color: showShadow ? DesignSystem.Colors.divider.opacity(0.3) : .clear,
                        radius: showShadow ? DesignSystem.Components.shadowCard.radius : 0,
                        x: showShadow ? DesignSystem.Components.shadowCard.x : 0,
                        y: showShadow ? DesignSystem.Components.shadowCard.y : 0
                    )
            )
    }
}

/// Elevated card for modals and overlays
struct GemiElevatedCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Components.radiusLarge)
                    .fill(DesignSystem.Colors.backgroundPrimary)
                    .shadow(
                        color: DesignSystem.Components.shadowElevated.color,
                        radius: DesignSystem.Components.shadowElevated.radius,
                        x: DesignSystem.Components.shadowElevated.x,
                        y: DesignSystem.Components.shadowElevated.y
                    )
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Applies Gemi's primary button style
    func gemiPrimaryButton(isLoading: Bool = false) -> some View {
        self.buttonStyle(GemiPrimaryButtonStyle(isLoading: isLoading))
    }
    
    /// Applies Gemi's secondary button style
    func gemiSecondaryButton() -> some View {
        self.buttonStyle(GemiSecondaryButtonStyle())
    }
    
    /// Applies Gemi's subtle button style
    func gemiSubtleButton() -> some View {
        self.buttonStyle(GemiSubtleButtonStyle())
    }
    
    /// Applies Gemi's card style
    func gemiCard(showShadow: Bool = true) -> some View {
        self.modifier(GemiCardStyle(showShadow: showShadow))
    }
    
    /// Applies Gemi's elevated card style
    func gemiElevatedCard() -> some View {
        self.modifier(GemiElevatedCardStyle())
    }
    
    /// Applies consistent padding for card content
    func gemiCardPadding() -> some View {
        self.padding(DesignSystem.Spacing.base)
    }
    
    /// Applies standard section spacing
    func gemiSectionSpacing() -> some View {
        self.padding(.bottom, DesignSystem.Spacing.large)
    }
}
