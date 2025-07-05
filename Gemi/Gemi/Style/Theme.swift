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
    
    struct Colors {
        static let primaryAccent = Color.accentColor
        static let secondaryText = Color.secondary
        static let tertiaryText = Color.secondary.opacity(0.7)
        static let divider = Color.secondary.opacity(0.15)
        static let hoverBackground = Color.secondary.opacity(0.08)
        static let selectedBackground = Color.accentColor.opacity(0.15)
        static let cardBackground = Color(nsColor: .controlBackgroundColor)
        static let windowBackground = Color(nsColor: .windowBackgroundColor)
    }
    
    struct Typography {
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let footnote = Font.system(size: 11, weight: .regular, design: .default)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.cornerRadius)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
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

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
    
    func hoverEffect() -> some View {
        modifier(HoverEffectModifier())
    }
}