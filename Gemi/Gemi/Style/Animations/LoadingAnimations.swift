//
//  LoadingAnimations.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

// MARK: - Skeleton Loading View

struct SkeletonLoadingView: View {
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(height: CGFloat = 20, cornerRadius: CGFloat = 8) {
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DesignSystem.Colors.backgroundSecondary)
            .frame(height: height)
            .skeleton()
    }
}

// MARK: - Card Skeleton

struct CardSkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date skeleton
            SkeletonLoadingView(height: 14, cornerRadius: 4)
                .frame(width: 120)
            
            // Title skeleton
            SkeletonLoadingView(height: 20, cornerRadius: 6)
            
            // Content skeleton
            VStack(alignment: .leading, spacing: 8) {
                SkeletonLoadingView(height: 16, cornerRadius: 4)
                SkeletonLoadingView(height: 16, cornerRadius: 4)
                    .frame(maxWidth: 200)
            }
            
            // Tags skeleton
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonLoadingView(height: 24, cornerRadius: 12)
                        .frame(width: 60)
                }
            }
        }
        .padding(20)
        .background(DesignSystem.Colors.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: DesignSystem.Colors.shadowLight,
            radius: 8,
            y: 4
        )
        .scaleEffect(isAnimating ? 1 : 0.98)
        .opacity(isAnimating ? 1 : 0.8)
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

// MARK: - Dots Loading Indicator

struct DotsLoadingIndicator: View {
    @State private var animationAmounts = [0.0, 0.0, 0.0]
    let dotSize: CGFloat
    let spacing: CGFloat
    
    init(dotSize: CGFloat = 8, spacing: CGFloat = 4) {
        self.dotSize = dotSize
        self.spacing = spacing
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(1 + animationAmounts[index] * 0.3)
                    .offset(y: -animationAmounts[index] * dotSize / 2)
            }
        }
        .onAppear {
            animateDots()
        }
    }
    
    private func animateDots() {
        for index in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.15)
            ) {
                animationAmounts[index] = 1
            }
        }
    }
}

// MARK: - Circular Progress Indicator

struct CircularProgressIndicator: View {
    @State private var rotation = 0.0
    let size: CGFloat
    let lineWidth: CGFloat
    
    init(size: CGFloat = 40, lineWidth: CGFloat = 3) {
        self.size = size
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    colors: [
                        DesignSystem.Colors.primary.opacity(0),
                        DesignSystem.Colors.primary
                    ],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
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

// MARK: - Writing Indicator

struct WritingIndicator: View {
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primary)
                .offset(x: offset)
                .opacity(opacity)
            
            Text("Writing...")
                .font(DesignSystem.Typography.footnote)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(DesignSystem.Animation.standard) {
                opacity = 1
            }
            
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                offset = 5
            }
        }
    }
}

// MARK: - Success Animation

struct SuccessAnimationView: View {
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var checkmarkTrim: CGFloat = 0
    let onComplete: (() -> Void)?
    
    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.success.opacity(0.1))
                .frame(width: 80, height: 80)
                .scaleEffect(scale)
            
            Circle()
                .stroke(DesignSystem.Colors.success, lineWidth: 3)
                .frame(width: 60, height: 60)
                .scaleEffect(scale)
            
            Path { path in
                path.move(to: CGPoint(x: 20, y: 30))
                path.addLine(to: CGPoint(x: 28, y: 38))
                path.addLine(to: CGPoint(x: 40, y: 22))
            }
            .trim(from: 0, to: checkmarkTrim)
            .stroke(DesignSystem.Colors.success, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .opacity(opacity)
        }
        .onAppear {
            animate()
        }
    }
    
    private func animate() {
        withAnimation(DesignSystem.Animation.playfulBounce) {
            scale = 1
        }
        
        withAnimation(DesignSystem.Animation.standard.delay(0.3)) {
            opacity = 1
            checkmarkTrim = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(DesignSystem.Animation.standard) {
                opacity = 0
                scale = 0.8
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onComplete?()
            }
        }
        
        HapticFeedback.success()
    }
}

// MARK: - Loading State Container

struct LoadingStateContainer<Content: View, LoadingContent: View>: View {
    let isLoading: Bool
    let content: () -> Content
    let loadingContent: () -> LoadingContent
    
    init(
        isLoading: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder loadingContent: @escaping () -> LoadingContent
    ) {
        self.isLoading = isLoading
        self.content = content
        self.loadingContent = loadingContent
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                loadingContent()
                    .transition(.opacity)
            } else {
                content()
                    .transition(.opacity)
            }
        }
        .animation(DesignSystem.Animation.standard, value: isLoading)
    }
}

// MARK: - View Extensions

extension View {
    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            CircularProgressIndicator()
                            
                            Text(message)
                                .font(DesignSystem.Fonts.body)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                        .padding(32)
                        .background(DesignSystem.Colors.backgroundPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(
                            color: DesignSystem.Colors.shadowMedium,
                            radius: 20,
                            y: 10
                        )
                    }
                    .transition(.opacity)
                }
            }
        )
    }
}