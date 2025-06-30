//
//  TooltipView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

// MARK: - Tooltip View

struct TooltipView: View {
    let text: String
    let maxWidth: CGFloat
    
    init(_ text: String, maxWidth: CGFloat = 250) {
        self.text = text
        self.maxWidth = maxWidth
    }
    
    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption1)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.85))
            )
            .frame(maxWidth: maxWidth)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Tooltip Modifier

struct TooltipModifier: ViewModifier {
    let tooltip: String
    let edge: Edge
    @State private var showTooltip = false
    
    init(_ tooltip: String, edge: Edge = .top) {
        self.tooltip = tooltip
        self.edge = edge
    }
    
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                withAnimation(DesignSystem.Animation.quick) {
                    showTooltip = hovering
                }
            }
            .overlay(
                Group {
                    if showTooltip {
                        TooltipView(tooltip)
                            .offset(tooltipOffset)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                removal: .opacity
                            ))
                    }
                }
            )
    }
    
    private var tooltipOffset: CGSize {
        switch edge {
        case .top:
            return CGSize(width: 0, height: -40)
        case .bottom:
            return CGSize(width: 0, height: 40)
        case .leading:
            return CGSize(width: -40, height: 0)
        case .trailing:
            return CGSize(width: 40, height: 0)
        }
    }
}

// MARK: - Coach Mark View

struct CoachMarkView: View {
    let title: String
    let message: String
    let targetFrame: CGRect
    let onDismiss: () -> Void
    
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1
    
    var body: some View {
        ZStack {
            // Dark overlay with cutout
            CoachMarkOverlay(targetFrame: targetFrame)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Highlight ring
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primary,
                            DesignSystem.Colors.secondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: targetFrame.width + 8, height: targetFrame.height + 8)
                .position(x: targetFrame.midX, y: targetFrame.midY)
                .scaleEffect(pulseScale)
                .opacity(isAnimating ? 0.8 : 1)
            
            // Coach mark bubble
            coachMarkBubble
                .position(bubblePosition)
        }
        .onAppear {
            withAnimation(
                DesignSystem.Animation.heartbeat
                    .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.05
                isAnimating = true
            }
        }
    }
    
    @ViewBuilder
    private var coachMarkBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
            
            Text(message)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Text("Got it!")
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.white)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primary,
                            DesignSystem.Colors.secondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(
            color: DesignSystem.Colors.primary.opacity(0.3),
            radius: 20,
            y: 10
        )
    }
    
    private var bubblePosition: CGPoint {
        let screenBounds = NSScreen.main?.frame ?? .zero
        let bubbleWidth: CGFloat = 300
        let bubbleHeight: CGFloat = 150
        let padding: CGFloat = 20
        
        var x = targetFrame.midX
        var y = targetFrame.maxY + bubbleHeight / 2 + padding
        
        // Adjust if bubble would go off screen
        if x - bubbleWidth / 2 < padding {
            x = bubbleWidth / 2 + padding
        } else if x + bubbleWidth / 2 > screenBounds.width - padding {
            x = screenBounds.width - bubbleWidth / 2 - padding
        }
        
        if y + bubbleHeight / 2 > screenBounds.height - padding {
            y = targetFrame.minY - bubbleHeight / 2 - padding
        }
        
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Coach Mark Overlay

struct CoachMarkOverlay: View {
    let targetFrame: CGRect
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Add the full screen rect
                path.addRect(geometry.frame(in: .local))
                
                // Subtract the target area
                let hole = RoundedRectangle(cornerRadius: 12)
                    .path(in: targetFrame.insetBy(dx: -4, dy: -4))
                path.addPath(hole)
            }
            .fill(Color.black.opacity(0.75), style: FillStyle(eoFill: true))
        }
    }
}

// MARK: - Coach Mark Modifier

struct CoachMarkModifier: ViewModifier {
    @Environment(OnboardingState.self) private var onboardingState
    let type: CoachMarkType
    let title: String
    let message: String
    
    @State private var showCoachMark = false
    @State private var targetFrame: CGRect = .zero
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            targetFrame = geometry.frame(in: .global)
                            checkIfShouldShow()
                        }
                }
            )
            .overlay(
                Group {
                    if showCoachMark {
                        CoachMarkView(
                            title: title,
                            message: message,
                            targetFrame: targetFrame
                        ) {
                            dismissCoachMark()
                        }
                    }
                }
            )
    }
    
    private func checkIfShouldShow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if onboardingState.shouldShowCoachMark(type) {
                withAnimation(DesignSystem.Animation.smooth) {
                    showCoachMark = true
                }
            }
        }
    }
    
    private func dismissCoachMark() {
        withAnimation(DesignSystem.Animation.standard) {
            showCoachMark = false
            onboardingState.markCoachMarkAsSeen(type)
        }
    }
}

// MARK: - View Extensions

extension View {
    func tooltip(_ text: String, edge: Edge = .top) -> some View {
        modifier(TooltipModifier(text, edge: edge))
    }
    
    func coachMark(
        _ type: CoachMarkType,
        title: String,
        message: String
    ) -> some View {
        modifier(CoachMarkModifier(type: type, title: title, message: message))
    }
}

// MARK: - Preview

#Preview("Tooltip") {
    HStack(spacing: 40) {
        Button("Hover me") {}
            .tooltip("This is a helpful tooltip!")
        
        Image(systemName: "info.circle")
            .tooltip("Click for more information", edge: .bottom)
    }
    .padding(100)
}

#Preview("Coach Mark") {
    VStack {
        Button("New Entry") {}
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    .frame(width: 400, height: 400)
    .overlay(
        CoachMarkView(
            title: "Create your first entry",
            message: "Click here to start writing in your journal. Your thoughts are always kept private and secure.",
            targetFrame: CGRect(x: 150, y: 180, width: 100, height: 40)
        ) {}
    )
}