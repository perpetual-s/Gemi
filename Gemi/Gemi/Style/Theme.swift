import SwiftUI

struct Theme {
    static let cornerRadius: CGFloat = 12
    static let smallCornerRadius: CGFloat = 8
    static let spacing: CGFloat = 16
    static let smallSpacing: CGFloat = 8
    static let largeSpacing: CGFloat = 24
    
    static let sidebarWidth: CGFloat = 280
    static let minWindowWidth: CGFloat = 1050
    static let minWindowHeight: CGFloat = 520
    
    static let animationDuration: Double = 0.25
    static let quickAnimation: Animation = .easeInOut(duration: 0.2)
    static let smoothAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.85)
    static let bounceAnimation: Animation = .spring(response: 0.5, dampingFraction: 0.65, blendDuration: 0)
    static let morphAnimation: Animation = .interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.25)
    
    // Enhanced animations
    static let gentleSpring: Animation = .spring(response: 0.4, dampingFraction: 0.8)
    static let microInteraction: Animation = .spring(response: 0.3, dampingFraction: 0.75)
    static let delightfulBounce: Animation = .spring(response: 0.4, dampingFraction: 0.6)
    
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
        
        // Enhanced color system
        static let chromaticRed = Color.red.opacity(0.02)
        static let chromaticGreen = Color.green.opacity(0.02)
        static let chromaticBlue = Color.blue.opacity(0.02)
        
        // Ambient colors based on time
        static func ambientColor(for hour: Int) -> Color {
            switch hour {
            case 5..<9: return Color.orange.opacity(0.2) // Morning
            case 9..<12: return Color.yellow.opacity(0.15) // Late morning
            case 12..<15: return Color.blue.opacity(0.1) // Afternoon
            case 15..<18: return Color.indigo.opacity(0.15) // Late afternoon
            case 18..<21: return Color.purple.opacity(0.2) // Evening
            default: return Color.indigo.opacity(0.25) // Night
            }
        }
        
        // Gradient mesh colors
        static let meshGradient1 = LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let meshGradient2 = RadialGradient(
            colors: [Color.pink.opacity(0.2), Color.clear],
            center: .center,
            startRadius: 50,
            endRadius: 200
        )
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
        
        // Unified section headers for consistent UI
        static let sectionHeader = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let sectionSubheader = Font.system(size: 13, weight: .medium, design: .rounded)
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
        
        // Advanced gradients
        static let aurora = LinearGradient(
            colors: [
                Color.blue.opacity(0.3),
                Color.purple.opacity(0.2),
                Color.pink.opacity(0.1),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let sunset = RadialGradient(
            colors: [
                Color.orange.opacity(0.3),
                Color.pink.opacity(0.2),
                Color.purple.opacity(0.1),
                Color.clear
            ],
            center: .topTrailing,
            startRadius: 100,
            endRadius: 400
        )
        
        static let ocean = LinearGradient(
            colors: [
                Color.blue.opacity(0.2),
                Color.cyan.opacity(0.15),
                Color.teal.opacity(0.1),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        
        // Dynamic gradient based on time
        static func timeBasedGradient(for date: Date = Date()) -> LinearGradient {
            let hour = Calendar.current.component(.hour, from: date)
            let colors: [Color]
            
            switch hour {
            case 5..<9:
                colors = [Color.orange.opacity(0.3), Color.yellow.opacity(0.2), Color.clear]
            case 9..<12:
                colors = [Color.blue.opacity(0.2), Color.cyan.opacity(0.15), Color.clear]
            case 12..<17:
                colors = [Color.blue.opacity(0.15), Color.green.opacity(0.1), Color.clear]
            case 17..<21:
                colors = [Color.purple.opacity(0.3), Color.pink.opacity(0.2), Color.clear]
            default:
                colors = [Color.indigo.opacity(0.4), Color.purple.opacity(0.3), Color.clear]
            }
            
            return LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    struct Effects {
        static let glassBlur: Material = .ultraThinMaterial
        static let contentBlur: Material = .regularMaterial
        static let sidebarBlur: Material = .thinMaterial
        
        // Enhanced effects for depth
        static let ultraLight = Color.white.opacity(0.03)
        static let glassGradient = LinearGradient(
            colors: [Color.white.opacity(0.08), Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let subtleGlow = Color.accentColor.opacity(0.15)
        
        // Advanced glass effects
        static func chromaticAberration() -> some View {
            ZStack {
                Color.red.opacity(0.02).offset(x: -1, y: 0)
                Color.green.opacity(0.02)
                Color.blue.opacity(0.02).offset(x: 1, y: 0)
            }
        }
        
        // Depth shadows
        static func depthShadow(elevation: Int) -> (color: Color, radius: CGFloat, y: CGFloat) {
            switch elevation {
            case 1: return (Color.black.opacity(0.08), 4, 2)
            case 2: return (Color.black.opacity(0.12), 8, 4)
            case 3: return (Color.black.opacity(0.16), 12, 6)
            case 4: return (Color.black.opacity(0.20), 16, 8)
            case 5: return (Color.black.opacity(0.24), 20, 10)
            default: return (Color.black.opacity(0.08), 4, 2)
            }
        }
        
        // Animated shimmer
        static let shimmer = LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(0.5),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
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
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base material layer
                    VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                    
                    // Gradient overlay
                    Theme.Gradients.glass
                        .opacity(isHovered ? 0.8 : 0.5)
                    
                    // Additional tint layer
                    Theme.Effects.ultraLight
                }
            )
            .cornerRadius(Theme.cornerRadius)
            .shadow(
                color: Theme.Colors.shadowColor.opacity(isHovered ? 0.2 : 0.1),
                radius: isHovered ? 12 : 8,
                x: 0,
                y: isHovered ? 6 : 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.2 : 0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .onHover { hovering in
                withAnimation(Theme.smoothAnimation) {
                    isHovered = hovering
                }
            }
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

// Enhanced glass effect modifier
struct EnhancedGlassModifier: ViewModifier {
    let material: NSVisualEffectView.Material
    let tintColor: Color
    let tintOpacity: Double
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectView(material: material, blendingMode: .behindWindow)
                    tintColor.opacity(tintOpacity)
                    Theme.Effects.glassGradient.opacity(0.3)
                }
            )
    }
}

// Depth shadow modifier
struct DepthShadowModifier: ViewModifier {
    let isElevated: Bool
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: Theme.Colors.shadowColor.opacity(isElevated ? 0.15 : 0.08),
                radius: isElevated ? 12 : 6,
                x: 0,
                y: isElevated ? 6 : 3
            )
            .shadow(
                color: Theme.Colors.primaryAccent.opacity(isElevated ? 0.05 : 0),
                radius: 20,
                x: 0,
                y: 8
            )
    }
}

// Animated button style with micro-interactions
struct AnimatedButtonStyle: ButtonStyle {
    @State private var isPressed = false
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : (isHovered ? 1.08 : 1.0))
            .brightness(isHovered ? 0.1 : 0)
            .animation(Theme.microInteraction, value: configuration.isPressed)
            .animation(Theme.gentleSpring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// Subtle pulse animation
struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    let color: Color
    let interval: Double
    
    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(color)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.3)
                    .animation(
                        Animation.easeOut(duration: interval)
                            .repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )
            .onAppear {
                isPulsing = true
            }
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
    
    func enhancedGlass(
        material: NSVisualEffectView.Material = .underWindowBackground,
        tint: Color = .clear,
        tintOpacity: Double = 0.05
    ) -> some View {
        modifier(EnhancedGlassModifier(
            material: material,
            tintColor: tint,
            tintOpacity: tintOpacity
        ))
    }
    
    func depthShadow(elevated: Bool = false) -> some View {
        modifier(DepthShadowModifier(isElevated: elevated))
    }
    
    func pulseEffect(color: Color = .accentColor, interval: Double = 1.5) -> some View {
        modifier(PulseEffect(color: color, interval: interval))
    }
}