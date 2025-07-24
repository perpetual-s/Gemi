//
//  GlassComponents.swift
//  Gemi
//
//  Glass morphism components for beautiful UI
//

import SwiftUI

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat
    var glowColor: Color
    var glowIntensity: Double
    
    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    init(
        cornerRadius: CGFloat = Theme.cornerRadius,
        glowColor: Color = .accentColor,
        glowIntensity: Double = 0.3,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.glowColor = glowColor
        self.glowIntensity = glowIntensity
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                ZStack {
                    // Base glass layer - more transparent
                    VisualEffectView.liquidGlass
                        .opacity(0.3) // Make the glass effect much more transparent
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.05 : 0.02), // Further reduced opacity
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Chromatic aberration effect
                    if isHovered {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.red.opacity(0.02),
                                        Color.green.opacity(0.02),
                                        Color.blue.opacity(0.02)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .blur(radius: 2)
                            .offset(x: 1, y: 1)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: Color.black.opacity(isPressed ? 0.1 : (isHovered ? 0.05 : 0.02)), // Much lighter shadows
                radius: isPressed ? 6 : (isHovered ? 15 : 8),
                x: 0,
                y: isPressed ? 3 : (isHovered ? 8 : 4)
            )
            .shadow(
                color: glowColor.opacity(isHovered ? glowIntensity : 0),
                radius: 30,
                x: 0,
                y: 0
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.15 : 0.05), // Even more subtle borders
                                Color.white.opacity(0.02),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5 // Thinner border
                    )
            )
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .animation(Theme.microInteraction, value: isPressed)
            .animation(Theme.gentleSpring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - Glass Button

struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var style: GlassButtonStyle
    
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var shimmerPhase: CGFloat = -1
    
    enum GlassButtonStyle {
        case primary
        case secondary
        case ghost
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .accentColor
            case .secondary: return .secondary
            case .ghost: return .clear
            }
        }
    }
    
    init(
        _ title: String,
        icon: String? = nil,
        style: GlassButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .rotationEffect(.degrees(isHovered ? 10 : 0))
                }
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(style == .ghost ? .primary : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Base layer
                    if style != .ghost {
                        Capsule()
                            .fill(style.backgroundColor)
                            .opacity(0.9)
                    }
                    
                    // Glass overlay
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.3 : 0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Shimmer effect
                    if isHovered {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.4),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: shimmerPhase * 200)
                            .mask(Capsule())
                    }
                }
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        Color.white.opacity(style == .ghost ? 0.2 : 0.3),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: style.backgroundColor.opacity(style == .ghost ? 0 : (isHovered ? 0.4 : 0.2)),
                radius: isHovered ? 20 : 10,
                x: 0,
                y: isHovered ? 8 : 4
            )
            .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
            .animation(Theme.bounceAnimation, value: isPressed)
            .animation(Theme.smoothAnimation, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                withAnimation(.linear(duration: 0.8)) {
                    shimmerPhase = 1
                }
            } else {
                shimmerPhase = -1
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: { }
        )
    }
}

// MARK: - Glass TextField

struct GlassTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String?
    var isSecure: Bool = false
    
    @State private var isFocused = false
    @FocusState private var textFieldFocus: Bool
    
    init(
        _ placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isFocused ? .accentColor : .secondary)
                    .scaleEffect(isFocused ? 1.1 : 1.0)
                    .animation(Theme.microInteraction, value: isFocused)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($textFieldFocus)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($textFieldFocus)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Base glass
                VisualEffectView.frostedGlass
                    .opacity(0.5)
                
                // Focus glow
                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(isFocused ? 0.1 : 0),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                .strokeBorder(
                    isFocused ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.2),
                    lineWidth: isFocused ? 2 : 1
                )
                .animation(Theme.quickAnimation, value: isFocused)
        )
        .shadow(
            color: Color.accentColor.opacity(isFocused ? 0.2 : 0),
            radius: isFocused ? 10 : 0,
            x: 0,
            y: 0
        )
        .animation(Theme.smoothAnimation, value: isFocused)
        .onChange(of: textFieldFocus) { _, newValue in
            isFocused = newValue
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 56
    
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var rotation: Double = 0
    
    var body: some View {
        Button(action: {
            withAnimation(Theme.delightfulBounce) {
                rotation += 360
            }
            action()
        }) {
            ZStack {
                // Shadow layer
                Circle()
                    .fill(Color.accentColor.opacity(0.3))
                    .blur(radius: 10)
                    .offset(y: isPressed ? 2 : 8)
                    .scaleEffect(isHovered ? 1.2 : 1.0)
                
                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor,
                                Color.accentColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Glass overlay
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
            }
            .frame(width: size, height: size)
            .scaleEffect(isPressed ? 0.9 : (isHovered ? 1.1 : 1.0))
            .animation(Theme.bounceAnimation, value: isPressed)
            .animation(Theme.smoothAnimation, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: { }
        )
    }
}

// MARK: - Glass Divider

struct GlassDivider: View {
    var orientation: Axis = .horizontal
    var thickness: CGFloat = 1
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base line
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                
                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.2),
                        Color.clear
                    ],
                    startPoint: orientation == .horizontal ? .leading : .top,
                    endPoint: orientation == .horizontal ? .trailing : .bottom
                )
                .blur(radius: 0.5)
            }
            .frame(
                width: orientation == .horizontal ? geometry.size.width : thickness,
                height: orientation == .horizontal ? thickness : geometry.size.height
            )
        }
        .frame(
            maxWidth: orientation == .horizontal ? .infinity : thickness,
            maxHeight: orientation == .horizontal ? thickness : .infinity
        )
    }
}

// MARK: - Convenience Extensions

extension View {
    func glassCard(
        cornerRadius: CGFloat = Theme.cornerRadius,
        glowColor: Color = .accentColor,
        glowIntensity: Double = 0.3
    ) -> some View {
        GlassCard(
            cornerRadius: cornerRadius,
            glowColor: glowColor,
            glowIntensity: glowIntensity
        ) {
            self
        }
    }
}