import SwiftUI

/// Enhanced multimodal processing view with real-time feedback
struct MultimodalProcessingView: View {
    @ObservedObject var multimodalService = MultimodalAIService.shared
    @ObservedObject var attachmentManager = AttachmentManager.shared
    @State private var isExpanded = false
    @State private var currentAnalysis: String = ""
    @State private var pulseAnimation = false
    @State private var hideTimer: Timer?
    
    var body: some View {
        if multimodalService.isProcessing || !currentAnalysis.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Header with animation
                HStack(spacing: 8) {
                    // Animated processing icon
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Theme.Colors.primaryAccent.opacity(0.3),
                                        Theme.Colors.primaryAccent.opacity(0.1)
                                    ],
                                    center: .center,
                                    startRadius: 4,
                                    endRadius: 12
                                )
                            )
                            .frame(width: 24, height: 24)
                            .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                            .opacity(pulseAnimation ? 0.6 : 1.0)
                        
                        Image(systemName: "wand.and.rays")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.primaryAccent)
                            .rotationEffect(.degrees(multimodalService.isProcessing ? 10 : 0))
                            .animation(
                                multimodalService.isProcessing ? 
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                                value: multimodalService.isProcessing
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(multimodalService.isProcessing ? "Analyzing attachments..." : "Analysis complete")
                            .font(Theme.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if !multimodalService.currentOperation.isEmpty {
                            Text(multimodalService.currentOperation)
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    // Expand/collapse button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                
                // Progress bar
                if multimodalService.isProcessing && multimodalService.processingProgress > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Capsule()
                                .fill(Theme.Colors.divider.opacity(0.2))
                                .frame(height: 4)
                            
                            // Progress
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Theme.Colors.primaryAccent,
                                            Theme.Colors.primaryAccent.opacity(0.8)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geometry.size.width * multimodalService.processingProgress,
                                    height: 4
                                )
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: multimodalService.processingProgress)
                        }
                    }
                    .frame(height: 4)
                }
                
                // Expanded details
                if isExpanded && !currentAnalysis.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                            .opacity(0.3)
                        
                        Text("AI Understanding:")
                            .font(Theme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.secondaryText)
                        
                        Text(currentAnalysis)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(.primary)
                            .lineLimit(isExpanded ? nil : 3)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.Colors.cardBackground.opacity(0.5))
                    .background(
                        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                            .opacity(0.3)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Theme.Colors.primaryAccent.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: Theme.Colors.primaryAccent.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .onAppear {
                pulseAnimation = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MultimodalAnalysisUpdate"))) { notification in
                if let analysis = notification.object as? String {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentAnalysis = analysis
                    }
                    
                    // Auto-hide after processing is done
                    hideTimer?.invalidate()
                    if !multimodalService.isProcessing {
                        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                            Task { @MainActor in
                                withAnimation(.easeOut(duration: 0.3)) {
                                    currentAnalysis = ""
                                }
                            }
                        }
                    }
                }
            }
            .onChange(of: multimodalService.isProcessing) { oldValue, newValue in
                if !newValue && !currentAnalysis.isEmpty {
                    // Processing finished, start hide timer
                    hideTimer?.invalidate()
                    hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                        Task { @MainActor in
                            withAnimation(.easeOut(duration: 0.3)) {
                                currentAnalysis = ""
                            }
                        }
                    }
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
        }
    }
}

/// Real-time analysis feedback view
struct AnalysisInsightView: View {
    let insight: String
    let type: InsightType
    @State private var isVisible = false
    
    enum InsightType {
        case text, object, face, scene, emotion
        
        var icon: String {
            switch self {
            case .text: return "text.viewfinder"
            case .object: return "cube.box"
            case .face: return "face.smiling"
            case .scene: return "photo"
            case .emotion: return "heart.text.square"
            }
        }
        
        var color: Color {
            switch self {
            case .text: return .blue
            case .object: return .green
            case .face: return .orange
            case .scene: return .purple
            case .emotion: return .pink
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: type.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(type.color)
                .frame(width: 20, height: 20)
            
            Text(insight)
                .font(Theme.Typography.footnote)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(type.color.opacity(0.1))
                .overlay(
                    Capsule()
                        .strokeBorder(type.color.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
                isVisible = true
            }
        }
    }
}