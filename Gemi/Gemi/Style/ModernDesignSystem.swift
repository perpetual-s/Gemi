//
//  ModernDesignSystem.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

/// Modern design system inspired by Claude macOS, Bear, and Craft
/// Features clean aesthetics, fluid typography, and delightful micro-animations
enum ModernDesignSystem {
    
    // MARK: - Colors
    
    enum Colors {
        // MARK: Primary Colors - Google DeepMind Pastel Blue Theme
        
        /// Primary accent - Warm pastel blue (#5B9BD5)
        static let primary = Color(hex: "5B9BD5")
        
        /// Primary hover state - Slightly deeper
        static let primaryHover = Color(hex: "4A8BC2")
        
        /// Primary pressed state - Pressed blue
        static let primaryPressed = Color(hex: "3A7BAF")
        
        // MARK: Background Colors - Warm Paper & Cozy Evening
        
        /// Warm paper background - Cream-white with warmth (#FEFCF8)
        static let backgroundPrimary = Color(hex: "FEFCF8")
        
        /// Cozy surface - Secondary warm background (#F8F6F2)
        static let backgroundSecondary = Color(hex: "F8F6F2")
        
        /// Journal page - Entry background with warmth (#FCFAF6)
        static let backgroundTertiary = Color(hex: "FCFAF6")
        
        /// Warm canvas background
        static let canvas = Color(hex: "FEFCF8")
        
        // MARK: Dark Mode Backgrounds - Cozy Evening
        
        /// Cozy evening primary - Deep warm brown (#1C1A17)
        static let backgroundPrimaryDark = Color(hex: "1C1A17")
        
        /// Cozy evening secondary - Warmer dark surface (#252219)
        static let backgroundSecondaryDark = Color(hex: "252219")
        
        /// Journal page dark - Entry background (#1F1D1A)
        static let backgroundTertiaryDark = Color(hex: "1F1D1A")
        
        /// Canvas evening - Warm dark canvas
        static let canvasDark = Color(hex: "1C1A17")
        
        // MARK: Text Colors - Warm & Readable
        
        /// Warm text - Primary text with brown undertones (#2D2B27)
        static let textPrimary = Color(hex: "2D2B27")
        
        /// Softer text - Secondary with warmth (#5D5B57)
        static let textSecondary = Color(hex: "5D5B57")
        
        /// Gentle text - Tertiary warm gray (#8D8B87)
        static let textTertiary = Color(hex: "8D8B87")
        
        /// Placeholder text - Subtle warm tone
        static let textPlaceholder = Color(hex: "B8B6B2")
        
        // MARK: Dark Mode Text - Warm Evening Tones
        
        /// Primary text (dark mode) - Warm cream (#E8E6E2)
        static let textPrimaryDark = Color(hex: "E8E6E2")
        
        /// Secondary text (dark mode) - Softer warm (#B8B6B2)
        static let textSecondaryDark = Color(hex: "B8B6B2")
        
        /// Tertiary text (dark mode) - Gentle warm (#888684)
        static let textTertiaryDark = Color(hex: "888684")
        
        // MARK: Mood Accent Colors
        
        /// Sunset orange for energetic moods
        static let moodEnergetic = Color(hex: "FF6B6B")
        
        /// Forest green for calm moods
        static let moodCalm = Color(hex: "51CF66")
        
        /// Lavender for reflective moods
        static let moodReflective = Color(hex: "9775FA")
        
        /// Golden yellow for happy moods
        static let moodHappy = Color(hex: "FFD43B")
        
        /// Deep blue for focused moods
        static let moodFocused = Color(hex: "4C6EF5")
        
        // MARK: Semantic Colors
        
        /// Success green
        static let success = Color(hex: "10B981")
        
        /// Warning amber
        static let warning = Color(hex: "F59E0B")
        
        /// Error red
        static let error = Color(hex: "EF4444")
        
        /// Info blue
        static let info = Color(hex: "3B82F6")
        
        // MARK: UI Colors
        
        /// Divider/separator color
        static let divider = Color(hex: "E5E5E5")
        
        /// Divider dark mode
        static let dividerDark = Color(hex: "262626")
        
        /// Border color
        static let border = Color(hex: "E0E0E0")
        
        /// Border dark mode
        static let borderDark = Color(hex: "2A2A2A")
        
        // MARK: Shadow Colors - Warm & Defined
        
        /// Warm shadow - Primary with brown tones
        static let warmShadow = Color(hex: "C4B8A8")
        
        /// Deep shadow - Deeper brown structure
        static let deepShadow = Color(hex: "B4A898")
        
        /// Gentle shadow - Subtle warm shadows
        static let gentleShadow = Color(hex: "D4C8B8")
        
        /// Legacy shadow support
        static let shadow = warmShadow.opacity(0.15)
        static let shadowMedium = warmShadow.opacity(0.25)
        static let shadowHeavy = deepShadow.opacity(0.35)
        
        // MARK: Glass Morphism
        
        /// Glass overlay background
        static let glassBackground = Color.white.opacity(0.7)
        static let glassBackgroundDark = Color.black.opacity(0.5)
        
        /// Glass border
        static let glassBorder = Color.white.opacity(0.2)
        static let glassBorderDark = Color.white.opacity(0.1)
        
        // MARK: - Adaptive Color Support
        
        /// Adaptive background that switches between light and dark
        static var adaptiveBackground: Color {
            Color(light: backgroundPrimary, dark: backgroundPrimaryDark)
        }
        
        /// Adaptive secondary background
        static var adaptiveBackgroundSecondary: Color {
            Color(light: backgroundSecondary, dark: backgroundSecondaryDark)
        }
        
        /// Adaptive tertiary background  
        static var adaptiveBackgroundTertiary: Color {
            Color(light: backgroundTertiary, dark: backgroundTertiaryDark)
        }
        
        /// Adaptive primary text
        static var adaptiveTextPrimary: Color {
            Color(light: textPrimary, dark: textPrimaryDark)
        }
        
        /// Adaptive secondary text
        static var adaptiveTextSecondary: Color {
            Color(light: textSecondary, dark: textSecondaryDark)
        }
        
        /// Adaptive tertiary text
        static var adaptiveTextTertiary: Color {
            Color(light: textTertiary, dark: textTertiaryDark)
        }
    }
    
    // MARK: - Typography
    
    enum Typography {
        // MARK: Font Families - Cozy Coffee Shop Warmth
        
        /// Headers - SF Pro Display for structured titles
        static let headerFamily = "SF Pro Display"
        
        /// Body text - SF Pro Rounded for warmth and friendliness
        static let bodyFamily = "SF Pro Rounded"
        
        /// Journal content - New York for personal, handwritten feel  
        static let journalFamily = "New York"
        
        /// Technical/UI text - SF Pro Text for interface elements
        static let uiFamily = "SF Pro Text"
        
        /// Monospace - SF Mono
        static let monoFamily = "SF Mono"
        
        // MARK: Font Sizes with 1.25 Ratio Scale (Warmer Sizing)
        
        /// Display (40px) - Reduced from 45 for more intimate feel
        static let displaySize: CGFloat = 40
        
        /// Title 1 (32px) - Reduced from 36 for cozy warmth
        static let title1Size: CGFloat = 32
        
        /// Title 2 (26px) - Reduced from 28 for comfortable reading
        static let title2Size: CGFloat = 26
        
        /// Title 3 (21px) - Slightly reduced for warmth
        static let title3Size: CGFloat = 21
        
        /// Headline (18px) - Comfortable emphasis
        static let headlineSize: CGFloat = 18
        
        /// Body (16px) - Increased from 14 for better readability
        static let bodySize: CGFloat = 16
        
        /// Callout (15px) - Reduced from 16 for subtlety
        static let calloutSize: CGFloat = 15
        
        /// Caption (13px) - Increased from 12 for warmth
        static let captionSize: CGFloat = 13
        
        /// Footnote (11px) - Standard small text
        static let footnoteSize: CGFloat = 11
        
        // MARK: Font Styles - Cozy Coffee Shop Implementation
        
        /// Display text for major headings - elegant but approachable
        static let display = Font.custom(headerFamily, size: displaySize, relativeTo: .largeTitle).weight(.light)
        
        /// Primary titles - confident but warm
        static let title1 = Font.custom(headerFamily, size: title1Size, relativeTo: .title).weight(.medium)
        
        /// Secondary titles - structured yet friendly
        static let title2 = Font.custom(headerFamily, size: title2Size, relativeTo: .title2).weight(.medium)
        
        /// Section headings - approachable emphasis
        static let title3 = Font.custom(bodyFamily, size: title3Size, relativeTo: .title3).weight(.semibold)
        
        /// Important text - warm prominence
        static let headline = Font.custom(bodyFamily, size: headlineSize, relativeTo: .headline).weight(.medium)
        
        /// Primary body text - cozy and readable
        static let body = Font.custom(bodyFamily, size: bodySize, relativeTo: .body).weight(.regular)
        
        /// Secondary text - gentle information
        static let callout = Font.custom(bodyFamily, size: calloutSize, relativeTo: .callout).weight(.regular)
        
        /// Small text - subtle but warm
        static let caption = Font.custom(bodyFamily, size: captionSize, relativeTo: .caption).weight(.regular)
        
        /// Tiny text - whisper-soft details
        static let footnote = Font.custom(bodyFamily, size: footnoteSize, relativeTo: .footnote).weight(.light)
        
        /// Journal writing - personal and intimate
        static let journal = Font.custom(journalFamily, size: bodySize + 2, relativeTo: .body).weight(.regular)
        
        /// Interface elements - clean and functional
        static let ui = Font.custom(uiFamily, size: bodySize, relativeTo: .body).weight(.regular)
        
        /// Technical/code text - structured clarity
        static let mono = Font.custom(monoFamily, size: bodySize - 1, relativeTo: .body).weight(.regular)
        
        // MARK: Line Heights - Generous Breathing Room
        
        static let displayLineHeight: CGFloat = 1.1
        static let headingLineHeight: CGFloat = 1.2
        static let bodyLineHeight: CGFloat = 1.5
        static let relaxedLineHeight: CGFloat = 1.7
    }
    
    // MARK: - Spacing (8px Grid System)
    
    enum Spacing {
        /// 4px
        static let xxs: CGFloat = 4
        
        /// 8px - base unit
        static let xs: CGFloat = 8
        
        /// 16px
        static let sm: CGFloat = 16
        
        /// 24px
        static let md: CGFloat = 24
        
        /// 32px
        static let lg: CGFloat = 32
        
        /// 40px
        static let xl: CGFloat = 40
        
        /// 48px
        static let xxl: CGFloat = 48
        
        /// 64px
        static let xxxl: CGFloat = 64
        
        /// 80px
        static let huge: CGFloat = 80
        
        // MARK: Layout Constants
        
        /// Sidebar width
        static let sidebarWidth: CGFloat = 260
        
        /// Timeline width
        static let timelineWidth: CGFloat = 380
        
        /// Maximum content width for optimal reading
        static let maxContentWidth: CGFloat = 680
        
        /// Touch target minimum
        static let touchTarget: CGFloat = 44
        
        /// Standard page margins
        static let pageMargin: CGFloat = 24
        
        /// Panel padding
        static let panelPadding: CGFloat = 32
        
        /// Card padding
        static let cardPadding: CGFloat = 20
    }
    
    // MARK: - Components
    
    enum Components {
        // MARK: Corner Radius
        
        /// Small radius (4px)
        static let radiusXS: CGFloat = 4
        
        /// Medium radius (8px)
        static let radiusSM: CGFloat = 8
        
        /// Default radius (12px)
        static let radiusMD: CGFloat = 12
        
        /// Large radius (16px)
        static let radiusLG: CGFloat = 16
        
        /// Extra large radius (20px)
        static let radiusXL: CGFloat = 20
        
        /// Full radius
        static let radiusFull: CGFloat = 9999
        
        // MARK: Shadows
        
        /// Subtle shadow for cards
        static let shadowSM = (
            color: Colors.shadow,
            radius: CGFloat(4),
            x: CGFloat(0),
            y: CGFloat(2)
        )
        
        /// Medium shadow for floating elements
        static let shadowMD = (
            color: Colors.shadowMedium,
            radius: CGFloat(12),
            x: CGFloat(0),
            y: CGFloat(4)
        )
        
        /// Large shadow for modals
        static let shadowLG = (
            color: Colors.shadowHeavy,
            radius: CGFloat(24),
            x: CGFloat(0),
            y: CGFloat(8)
        )
        
        /// Glass morphism shadow
        static let shadowGlass = (
            color: Color.black.opacity(0.1),
            radius: CGFloat(16),
            x: CGFloat(0),
            y: CGFloat(8)
        )
        
        // MARK: Animation Durations
        
        /// Instant (100ms)
        static let durationInstant: Double = 0.1
        
        /// Fast (200ms)
        static let durationFast: Double = 0.2
        
        /// Normal (300ms)
        static let durationNormal: Double = 0.3
        
        /// Slow (500ms)
        static let durationSlow: Double = 0.5
        
        // MARK: Component Heights
        
        /// Button heights
        static let buttonHeightSM: CGFloat = 32
        static let buttonHeightMD: CGFloat = 40
        static let buttonHeightLG: CGFloat = 48
        
        /// Input field height
        static let inputHeight: CGFloat = 40
        
        /// Toolbar height
        static let toolbarHeight: CGFloat = 56
        
        /// Navigation bar height
        static let navBarHeight: CGFloat = 64
    }
    
    // MARK: - Animations
    
    enum Animation {
        /// Spring animation for delightful interactions
        static let spring = SwiftUI.Animation.spring(
            response: 0.4,
            dampingFraction: 0.8,
            blendDuration: 0
        )
        
        /// Smooth ease out for transitions
        static let easeOut = SwiftUI.Animation.easeOut(duration: Components.durationNormal)
        
        /// Quick ease out for micro-interactions
        static let easeOutFast = SwiftUI.Animation.easeOut(duration: Components.durationFast)
        
        /// Gentle ease in-out for subtle animations
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: Components.durationNormal)
        
        /// Bounce animation for playful elements
        static let bounce = SwiftUI.Animation.interpolatingSpring(
            stiffness: 300,
            damping: 15
        )
        
        /// Smooth hover animation
        static let hover = SwiftUI.Animation.easeOut(duration: Components.durationFast)
    }
}

// MARK: - Color Extensions

extension Color {
    /// Create an adaptive color that switches between light and dark mode
    init(light: Color, dark: Color) {
        #if canImport(AppKit)
        self = Color(NSColor(name: nil) { appearance in
            return appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? 
                NSColor(dark) : NSColor(light)
        })
        #else
        self = light
        #endif
    }
    
    /// Get NSColor representation for macOS
    var nsColor: NSColor {
        return NSColor(self)
    }
}

// MARK: - Hex Color Support

extension Color {
    /// Create color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Adaptive Colors

struct AdaptiveColor: View {
    let light: Color
    let dark: Color
    @Environment(\.colorScheme) var colorScheme
    
    var color: Color {
        colorScheme == .dark ? dark : light
    }
    
    var body: some View {
        color
    }
}

// MARK: - Component Styles

// Modern button style with smooth animations
struct ModernButtonStyle: ButtonStyle {
    enum ButtonVariant {
        case primary
        case secondary
        case ghost
    }
    
    let variant: ButtonVariant
    let size: ButtonSize = .medium
    
    @State private var isHovered = false
    
    enum ButtonSize {
        case small
        case medium
        case large
        
        var height: CGFloat {
            switch self {
            case .small: return ModernDesignSystem.Components.buttonHeightSM
            case .medium: return ModernDesignSystem.Components.buttonHeightMD
            case .large: return ModernDesignSystem.Components.buttonHeightLG
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .small: return ModernDesignSystem.Spacing.xs
            case .medium: return ModernDesignSystem.Spacing.sm
            case .large: return ModernDesignSystem.Spacing.md
            }
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ModernDesignSystem.Typography.callout)
            .fontWeight(.medium)
            .foregroundColor(foregroundColor)
            .frame(height: size.height)
            .padding(.horizontal, size.padding)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                    .stroke(borderColor, lineWidth: variant == .secondary ? 1 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(
                color: shadowColor,
                radius: isHovered ? 8 : 4,
                x: 0,
                y: isHovered ? 4 : 2
            )
            .onHover { hovering in
                withAnimation(ModernDesignSystem.Animation.hover) {
                    isHovered = hovering
                }
            }
            .animation(ModernDesignSystem.Animation.spring, value: configuration.isPressed)
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary, .ghost:
            return ModernDesignSystem.Colors.primary
        }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return isPressed ? ModernDesignSystem.Colors.primaryPressed : 
                   isHovered ? ModernDesignSystem.Colors.primaryHover :
                   ModernDesignSystem.Colors.primary
        case .secondary:
            return isPressed ? ModernDesignSystem.Colors.primary.opacity(0.1) :
                   isHovered ? ModernDesignSystem.Colors.primary.opacity(0.05) :
                   Color.clear
        case .ghost:
            return isPressed ? ModernDesignSystem.Colors.primary.opacity(0.1) :
                   isHovered ? ModernDesignSystem.Colors.primary.opacity(0.05) :
                   Color.clear
        }
    }
    
    private var borderColor: Color {
        switch variant {
        case .secondary:
            return ModernDesignSystem.Colors.primary
        default:
            return Color.clear
        }
    }
    
    private var shadowColor: Color {
        switch variant {
        case .primary:
            return ModernDesignSystem.Colors.primary.opacity(0.3)
        default:
            return Color.clear
        }
    }
}

// Floating action button style
struct FloatingActionButtonStyle: ViewModifier {
    @State private var isHovered = false
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .frame(width: 56, height: 56)
            .background(
                Circle()
                    .fill(ModernDesignSystem.Colors.primary)
                    .shadow(
                        color: ModernDesignSystem.Components.shadowMD.color,
                        radius: isHovered ? 16 : ModernDesignSystem.Components.shadowMD.radius,
                        x: 0,
                        y: isHovered ? 6 : ModernDesignSystem.Components.shadowMD.y
                    )
            )
            .foregroundColor(.white)
            .scaleEffect(isPressed ? 0.95 : isHovered ? 1.05 : 1.0)
            .onHover { hovering in
                withAnimation(ModernDesignSystem.Animation.hover) {
                    isHovered = hovering
                }
            }
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
                withAnimation(ModernDesignSystem.Animation.spring) {
                    isPressed = pressing
                }
            } perform: {}
    }
}

// Glass morphism card style
struct GlassCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                    .fill(
                        colorScheme == .dark ?
                        ModernDesignSystem.Colors.glassBackgroundDark :
                        ModernDesignSystem.Colors.glassBackground
                    )
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                    .stroke(
                        colorScheme == .dark ?
                        ModernDesignSystem.Colors.glassBorderDark :
                        ModernDesignSystem.Colors.glassBorder,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: ModernDesignSystem.Components.shadowGlass.color,
                radius: ModernDesignSystem.Components.shadowGlass.radius,
                x: ModernDesignSystem.Components.shadowGlass.x,
                y: ModernDesignSystem.Components.shadowGlass.y
            )
    }
}

// Modern card style
struct ModernCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let elevation: CardElevation
    
    enum CardElevation {
        case low
        case medium
        case high
        
        var shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            switch self {
            case .low: return ModernDesignSystem.Components.shadowSM
            case .medium: return ModernDesignSystem.Components.shadowMD
            case .high: return ModernDesignSystem.Components.shadowLG
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                    .fill(
                        colorScheme == .dark ?
                        ModernDesignSystem.Colors.backgroundSecondaryDark :
                        ModernDesignSystem.Colors.backgroundPrimary
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                    .stroke(ModernDesignSystem.Colors.border, lineWidth: 1)
            )
            .shadow(
                color: elevation.shadow.color,
                radius: elevation.shadow.radius,
                x: elevation.shadow.x,
                y: elevation.shadow.y
            )
    }
}

// MARK: - View Extensions

extension View {
    // Button styles
    func modernButton(_ variant: ModernButtonStyle.ButtonVariant = .primary) -> some View {
        self.buttonStyle(ModernButtonStyle(variant: variant))
    }
    
    // Floating action button
    func floatingActionButton() -> some View {
        self.modifier(FloatingActionButtonStyle())
    }
    
    // Card styles
    func glassCard() -> some View {
        self.modifier(GlassCardStyle())
    }
    
    func modernCard(elevation: ModernCardStyle.CardElevation = .medium) -> some View {
        self.modifier(ModernCardStyle(elevation: elevation))
    }
    
    // Spacing helpers
    func modernPadding(_ edges: Edge.Set = .all, _ size: CGFloat? = nil) -> some View {
        self.padding(edges, size ?? ModernDesignSystem.Spacing.md)
    }
    
    func cardPadding() -> some View {
        self.padding(ModernDesignSystem.Spacing.cardPadding)
    }
    
    // Typography helpers
    func titleStyle() -> some View {
        self.font(ModernDesignSystem.Typography.title2)
            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
    }
    
    func bodyStyle() -> some View {
        self.font(ModernDesignSystem.Typography.body)
            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            .lineSpacing(ModernDesignSystem.Typography.bodySize * (ModernDesignSystem.Typography.bodyLineHeight - 1))
    }
    
    func captionStyle() -> some View {
        self.font(ModernDesignSystem.Typography.caption)
            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
    }
}

// MARK: - Reusable Components

// Modern text field
struct ModernTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    
    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    
    init(placeholder: String, text: Binding<String>, icon: String? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .font(.system(size: 16))
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(ModernDesignSystem.Typography.body)
                .focused($isFocused)
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
        .frame(height: ModernDesignSystem.Components.inputHeight)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                .fill(ModernDesignSystem.Colors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                        .stroke(
                            isFocused ? ModernDesignSystem.Colors.primary :
                            isHovered ? ModernDesignSystem.Colors.border :
                            Color.clear,
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        )
        .onHover { hovering in
            withAnimation(ModernDesignSystem.Animation.hover) {
                isHovered = hovering
            }
        }
        .animation(ModernDesignSystem.Animation.easeOutFast, value: isFocused)
    }
}

// Loading spinner with smooth animation
struct ModernLoadingSpinner: View {
    @State private var rotation = 0.0
    let size: CGFloat
    
    init(size: CGFloat = 24) {
        self.size = size
    }
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    colors: [
                        ModernDesignSystem.Colors.primary,
                        ModernDesignSystem.Colors.primary.opacity(0.5),
                        ModernDesignSystem.Colors.primary.opacity(0)
                    ],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(
                    .linear(duration: 1)
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
            }
    }
}

// Mood indicator pill
struct MoodIndicator: View {
    let mood: Mood
    let size: Size
    
    enum Mood: String, CaseIterable {
        case energetic
        case calm
        case reflective
        case happy
        case focused
        case anxious
        case melancholic
        case frustrated
        case grateful
        case hopeful
        case excited
        
        var color: Color {
            switch self {
            case .energetic: return ModernDesignSystem.Colors.moodEnergetic
            case .calm: return ModernDesignSystem.Colors.moodCalm
            case .reflective: return ModernDesignSystem.Colors.moodReflective
            case .happy: return ModernDesignSystem.Colors.moodHappy
            case .focused: return ModernDesignSystem.Colors.moodFocused
            case .anxious: return ModernDesignSystem.Colors.warning
            case .melancholic: return ModernDesignSystem.Colors.moodReflective.opacity(0.7)
            case .frustrated: return ModernDesignSystem.Colors.error.opacity(0.8)
            case .grateful: return ModernDesignSystem.Colors.success
            case .hopeful: return ModernDesignSystem.Colors.info
            case .excited: return ModernDesignSystem.Colors.moodEnergetic.opacity(0.9)
            }
        }
        
        var icon: String {
            switch self {
            case .energetic: return "flame.fill"
            case .calm: return "leaf.fill"
            case .reflective: return "moon.stars.fill"
            case .happy: return "sun.max.fill"
            case .focused: return "target"
            case .anxious: return "exclamationmark.triangle.fill"
            case .melancholic: return "cloud.rain.fill"
            case .frustrated: return "bolt.fill"
            case .grateful: return "heart.fill"
            case .hopeful: return "star.fill"
            case .excited: return "sparkles"
            }
        }
        
        func toString() -> String {
            return self.rawValue
        }
    }
    
    enum Size {
        case small
        case medium
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 8
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: mood.icon)
                .font(.system(size: size.iconSize))
            
            if size == .medium {
                Text(String(describing: mood).capitalized)
                    .font(ModernDesignSystem.Typography.caption)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, size.padding)
        .padding(.vertical, size.padding / 2)
        .background(
            Capsule()
                .fill(mood.color)
        )
    }
}