//
//  PerformanceOptimizer.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI
import Combine

/// Manages performance optimizations for smooth 60fps animations and responsive UI
@Observable
final class PerformanceOptimizer {
    
    // MARK: - Properties
    
    /// Tracks if animations should be reduced for performance
    private(set) var shouldReduceAnimations = false
    
    /// Tracks if the app is under memory pressure
    private(set) var isMemoryConstrained = false
    
    /// Animation namespace for smooth transitions
    let animationNamespace = Namespace().wrappedValue
    
    // MARK: - Animation Helpers
    
    /// Premium spring animation for UI elements
    static let springAnimation = Animation.spring(
        response: 0.35,
        dampingFraction: 0.86,
        blendDuration: 0.25
    )
    
    /// Smooth ease-in-out animation
    static let smoothAnimation = Animation.timingCurve(
        0.4, 0.0, 0.2, 1.0,
        duration: 0.3
    )
    
    /// Quick interaction animation
    static let quickAnimation = Animation.timingCurve(
        0.25, 0.1, 0.25, 1.0,
        duration: 0.2
    )
    
    /// Gentle animation for subtle effects
    static let gentleAnimation = Animation.easeInOut(duration: 0.4)
    
    // MARK: - Performance Monitoring
    
    func startMonitoring() {
        // Monitor memory pressure
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                self?.checkPerformanceState()
            }
            .store(in: &cancellables)
    }
    
    private func checkPerformanceState() {
        let processInfo = ProcessInfo.processInfo
        
        // Check if we should reduce animations
        shouldReduceAnimations = processInfo.isLowPowerModeEnabled
        
        // Check memory pressure
        let memoryInfo = processInfo.physicalMemory
        let availableMemory = memoryInfo - processInfo.systemUptime.bitPattern
        isMemoryConstrained = availableMemory < 1_073_741_824 // Less than 1GB
    }
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Performance View Modifiers

struct HighPerformanceScrollView: ViewModifier {
    @Environment(PerformanceOptimizer.self) private var optimizer
    
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollBounceBehavior(.basedOnSize)
    }
}

struct OptimizedAnimation: ViewModifier {
    @Environment(PerformanceOptimizer.self) private var optimizer
    let animation: Animation
    
    func body(content: Content) -> some View {
        content
            .animation(
                optimizer.shouldReduceAnimations ? .none : animation,
                value: UUID()
            )
    }
}

struct LazyRenderingModifier: ViewModifier {
    @Environment(PerformanceOptimizer.self) private var optimizer
    let threshold: CGFloat = 100
    
    func body(content: Content) -> some View {
        content
            .drawingGroup(opaque: false, colorMode: .linear)
            .compositingGroup()
    }
}

// MARK: - Metal Performance Shaders

struct MetalBlurEffect: ViewModifier {
    let radius: CGFloat
    @Environment(PerformanceOptimizer.self) private var optimizer
    
    func body(content: Content) -> some View {
        content
            .blur(radius: optimizer.shouldReduceAnimations ? 0 : radius)
            .drawingGroup()
    }
}

// MARK: - View Extensions

extension View {
    func highPerformanceScroll() -> some View {
        self.modifier(HighPerformanceScrollView())
    }
    
    func optimizedAnimation(_ animation: Animation = PerformanceOptimizer.springAnimation) -> some View {
        self.modifier(OptimizedAnimation(animation: animation))
    }
    
    func lazyRendering() -> some View {
        self.modifier(LazyRenderingModifier())
    }
    
    func metalBlur(radius: CGFloat) -> some View {
        self.modifier(MetalBlurEffect(radius: radius))
    }
}

// MARK: - Image Loading Optimization

struct OptimizedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (Image) -> Content
    
    @State private var image: Image?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                content(image)
            } else {
                ProgressView()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        isLoading = true
        
        Task {
            if let data = try? Data(contentsOf: url),
               let nsImage = NSImage(data: data) {
                await MainActor.run {
                    self.image = Image(nsImage: nsImage)
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Memory-Efficient List

struct OptimizedList<Content: View>: View {
    let content: Content
    @Environment(PerformanceOptimizer.self) private var optimizer
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                content
            }
        }
        .highPerformanceScroll()
    }
}