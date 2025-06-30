//
//  Illustrations.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

// MARK: - Journal Illustration

struct JournalIllustration: View {
    @State private var isAnimating = false
    let size: CGFloat
    
    init(size: CGFloat = 120) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Pages stack effect
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: size * 0.1)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 1 - Double(index) * 0.02),
                                Color(white: 0.98 - Double(index) * 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size * 1.2)
                    .shadow(
                        color: DesignSystem.Colors.shadowLight,
                        radius: 4 + Double(index) * 2,
                        x: -2 - Double(index) * 2,
                        y: 2 + Double(index) * 2
                    )
                    .rotationEffect(.degrees(-2 + Double(index) * 2))
                    .offset(
                        x: -Double(index) * 4,
                        y: -Double(index) * 4
                    )
            }
            
            // Main journal
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.1)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.99, green: 0.98, blue: 0.96),
                                Color(red: 0.97, green: 0.96, blue: 0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size * 1.2)
                
                // Lines
                VStack(spacing: size * 0.08) {
                    ForEach(0..<6) { _ in
                        Rectangle()
                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                            .frame(height: 1)
                            .padding(.horizontal, size * 0.15)
                    }
                }
                .offset(y: size * 0.1)
                
                // Bookmark
                Path { path in
                    path.move(to: CGPoint(x: size * 0.7, y: 0))
                    path.addLine(to: CGPoint(x: size * 0.7, y: size * 0.3))
                    path.addLine(to: CGPoint(x: size * 0.75, y: size * 0.25))
                    path.addLine(to: CGPoint(x: size * 0.8, y: size * 0.3))
                    path.addLine(to: CGPoint(x: size * 0.8, y: 0))
                }
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primary,
                            DesignSystem.Colors.primary.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .shadow(
                color: DesignSystem.Colors.shadowMedium,
                radius: 12,
                x: 0,
                y: 6
            )
            .scaleEffect(isAnimating ? 1.05 : 1)
            .rotationEffect(.degrees(isAnimating ? 2 : 0))
        }
        .onAppear {
            withAnimation(
                DesignSystem.Animation.breathing
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Privacy Shield Illustration

struct PrivacyShieldIllustration: View {
    @State private var isAnimating = false
    let size: CGFloat
    
    init(size: CGFloat = 100) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            DesignSystem.Colors.success.opacity(0.2),
                            DesignSystem.Colors.success.opacity(0)
                        ],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
            
            // Shield shape
            ShieldShape()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.success,
                            DesignSystem.Colors.success.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size * 1.2)
                .overlay(
                    // Lock icon
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.3, weight: .bold))
                        .foregroundStyle(.white)
                )
                .shadow(
                    color: DesignSystem.Colors.success.opacity(0.3),
                    radius: 10,
                    y: 5
                )
                .scaleEffect(isAnimating ? 1 : 0.95)
        }
        .onAppear {
            withAnimation(
                DesignSystem.Animation.breathing
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - AI Sparkle Illustration

struct AISparkleIllustration: View {
    @State private var sparkleOffsets: [CGSize] = Array(repeating: .zero, count: 6)
    @State private var sparkleOpacities: [Double] = Array(repeating: 0, count: 6)
    let size: CGFloat
    
    init(size: CGFloat = 80) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Central AI brain
            Circle()
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
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "brain")
                        .font(.system(size: size * 0.5, weight: .light))
                        .foregroundStyle(.white)
                )
            
            // Sparkles
            ForEach(0..<6) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.2, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primary,
                                DesignSystem.Colors.secondary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(sparkleOffsets[index])
                    .opacity(sparkleOpacities[index])
                    .rotationEffect(.degrees(Double(index) * 60))
            }
        }
        .onAppear {
            animateSparkles()
        }
    }
    
    private func animateSparkles() {
        for index in 0..<6 {
            let angle = Double(index) * .pi / 3
            let delay = Double(index) * 0.1
            
            withAnimation(
                Animation.easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
            ) {
                sparkleOffsets[index] = CGSize(
                    width: cos(angle) * size * 0.7,
                    height: sin(angle) * size * 0.7
                )
                sparkleOpacities[index] = 0.8
            }
        }
    }
}

// MARK: - Pencil Writing Illustration

struct PencilWritingIllustration: View {
    @State private var writingProgress: CGFloat = 0
    let size: CGFloat
    
    init(size: CGFloat = 100) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Paper
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(Color(red: 0.99, green: 0.98, blue: 0.96))
                .frame(width: size, height: size * 1.2)
                .shadow(
                    color: DesignSystem.Colors.shadowLight,
                    radius: 6,
                    y: 3
                )
            
            // Writing lines
            VStack(alignment: .leading, spacing: size * 0.08) {
                ForEach(0..<3) { index in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(DesignSystem.Colors.primary)
                            .frame(
                                width: size * 0.7 * (index == 0 ? writingProgress : (index == 1 ? writingProgress * 0.6 : 0)),
                                height: 2
                            )
                        
                        Spacer()
                    }
                    .frame(width: size * 0.7)
                }
            }
            .padding(.horizontal, size * 0.15)
            
            // Pencil
            Group {
                Image(systemName: "pencil")
                    .font(.system(size: size * 0.3, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.8, green: 0.6, blue: 0.3),
                                Color(red: 0.9, green: 0.7, blue: 0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(45))
                    .offset(
                        x: -size * 0.35 + (size * 0.7 * writingProgress),
                        y: -size * 0.3
                    )
            }
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 3)
                    .repeatForever(autoreverses: true)
            ) {
                writingProgress = 1
            }
        }
    }
}

// MARK: - Supporting Shapes

struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width * 0.5, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: width, y: height * 0.3),
            control: CGPoint(x: width, y: 0)
        )
        path.addLine(to: CGPoint(x: width, y: height * 0.6))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control: CGPoint(x: width * 0.5, y: height * 0.8)
        )
        path.addQuadCurve(
            to: CGPoint(x: 0, y: height * 0.6),
            control: CGPoint(x: width * 0.5, y: height * 0.8)
        )
        path.addLine(to: CGPoint(x: 0, y: height * 0.3))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.5, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        
        return path
    }
}