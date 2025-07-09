import SwiftUI

struct Theme {
    static let cornerRadius: CGFloat = 12
    static let smallCornerRadius: CGFloat = 8
    static let spacing: CGFloat = 16
    static let smallSpacing: CGFloat = 8
    static let largeSpacing: CGFloat = 24
    
    static let sidebarWidth: CGFloat = 280
    static let minWindowWidth: CGFloat = 900
    static let minWindowHeight: CGFloat = 600
    
    static let animationDuration: Double = 0.25
    static let quickAnimation: Animation = .easeInOut(duration: 0.2)
    static let smoothAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.85)
    static let bounceAnimation: Animation = .spring(response: 0.5, dampingFraction: 0.65, blendDuration: 0)
    static let morphAnimation: Animation = .interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.25)
    
    struct Colors {
        static let primaryAccent = Color.accentColor
        static let secondaryText = Color.secondary
        static let tertiaryText = Color.secondary.opacity(0.7)
        static let divider = Color.secondary.opacity(0.15)
        static let hoverBackground = Color.secondary.opacity(0.08)
        static let selectedBackground = Color.accentColor.opacity(0.15)
        static let cardBackground = Color(nsColor: .controlBackgroundColor)
        static let windowBackground = Color(nsColor: .windowBackgroundColor)
        static let glassTint = Color.white.opacity(0.05)
        static let shadowColor = Color.black.opacity(0.1)
        static let glowColor = Color.accentColor.opacity(0.3)
    }
    
    struct Typography {
        static let heroTitle = Font.system(size: 36, weight: .bold, design: .serif)
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let subtitle = Font.system(size: 18, weight: .regular, design: .default)
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let footnote = Font.system(size: 11, weight: .regular, design: .default)
        static let greeting = Font.system(size: 24, weight: .light, design: .rounded)
    }
    
    struct Gradients {
        static let primary = LinearGradient(
            gradient: Gradient(colors: [
                Color.accentColor,
                Color.accentColor.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let glass = LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.1),
                Color.white.opacity(0.05),
                Color.clear
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    struct Effects {
        static let glassBlur: Material = .ultraThinMaterial
        static let contentBlur: Material = .regularMaterial
        static let sidebarBlur: Material = .thinMaterial
    }
}

struct CardModifier: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Theme.Colors.cardBackground
                    
                    // Subtle gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Theme.Colors.glassTint,
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(isHovered ? 0.8 : 0.3)
                }
            )
            .cornerRadius(Theme.cornerRadius)
            .shadow(
                color: Theme.Colors.shadowColor.opacity(isHovered ? 0.15 : 0.1),
                radius: isHovered ? 8 : 4,
                x: 0,
                y: isHovered ? 4 : 2
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .onHover { hovering in
                withAnimation(Theme.quickAnimation) {
                    isHovered = hovering
                }
            }
    }
}

struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                    .fill(isHovered ? Theme.Colors.hoverBackground : Color.clear)
            )
            .onHover { hovering in
                withAnimation(Theme.quickAnimation) {
                    isHovered = hovering
                }
            }
    }
}


struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Theme.Gradients.glass)
            .cornerRadius(Theme.cornerRadius)
            .shadow(color: Theme.Colors.shadowColor, radius: 8, x: 0, y: 4)
    }
}

struct FloatingButtonModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(
                color: Theme.Colors.shadowColor.opacity(isPressed ? 0.2 : 0.3),
                radius: isPressed ? 4 : 8,
                x: 0,
                y: isPressed ? 2 : 4
            )
            .onTapGesture { }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                pressing: { pressing in
                    withAnimation(Theme.bounceAnimation) {
                        isPressed = pressing
                    }
                },
                perform: { }
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
    
    func glassCardStyle() -> some View {
        modifier(GlassCardModifier())
    }
    
    func hoverEffect() -> some View {
        modifier(HoverEffectModifier())
    }
    
    func floatingButton() -> some View {
        modifier(FloatingButtonModifier())
    }
}