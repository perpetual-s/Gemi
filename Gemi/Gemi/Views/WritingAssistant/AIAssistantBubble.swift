import SwiftUI

/// Floating AI assistant bubble that provides intelligent writing suggestions
struct AIAssistantBubble: View {
    @Binding var isVisible: Bool
    @Binding var isExpanded: Bool
    @State private var suggestion: String = ""
    @State private var isThinking: Bool = false
    @State private var bubbleOpacity: Double = 0
    @State private var scale: Double = 0.8
    @State private var offset: CGSize = .zero
    @State private var isDragging: Bool = false
    
    let onSuggestionAccepted: (String) -> Void
    let position: BubblePosition
    
    enum BubblePosition {
        case topRight
        case bottomRight
        case custom(x: CGFloat, y: CGFloat)
        
        var offset: CGSize {
            switch self {
            case .topRight:
                return CGSize(width: -30, height: 30)
            case .bottomRight:
                return CGSize(width: -30, height: -30)
            case .custom(let x, let y):
                return CGSize(width: x, height: y)
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8, anchor: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.8, anchor: .trailing).combined(with: .opacity)
                    ))
            }
            
            // Main bubble button
            bubbleButton
        }
        .offset(isDragging ? offset : position.offset)
        .opacity(bubbleOpacity)
        .scaleEffect(scale)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scale)
        .animation(.easeOut(duration: 0.3), value: bubbleOpacity)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isExpanded {
                        isDragging = true
                        offset = CGSize(
                            width: position.offset.width + value.translation.width,
                            height: position.offset.height + value.translation.height
                        )
                    }
                }
                .onEnded { _ in
                    // Optional: Save custom position
                }
        )
        .onAppear {
            // Delay slightly to ensure view is properly laid out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.4)) {
                    bubbleOpacity = 1
                    scale = 1
                }
            }
        }
    }
    
    private var bubbleButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
            }
        } label: {
            ZStack {
                // Background gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.primaryAccent, Theme.Colors.primaryAccent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                // Shadow and glow
                Circle()
                    .stroke(Theme.Colors.primaryAccent.opacity(0.3), lineWidth: 1)
                    .frame(width: 56, height: 56)
                    .shadow(color: Theme.Colors.primaryAccent.opacity(0.4), radius: 10, x: 0, y: 4)
                
                // Icon with animation
                if isThinking {
                    ThinkingIndicator()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: isExpanded ? "xmark" : "wand.and.stars")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                        .symbolEffect(.pulse, value: !isExpanded)
                }
            }
        }
        .buttonStyle(BubbleButtonStyle())
        .help("AI Writing Assistant")
    }
    
    private var expandedContent: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Suggestion card
            if !suggestion.isEmpty && !isThinking {
                SuggestionCard(
                    suggestion: suggestion,
                    onAccept: {
                        onSuggestionAccepted(suggestion)
                        withAnimation {
                            suggestion = ""
                            isExpanded = false
                        }
                    },
                    onRegenerate: {
                        generateSuggestion()
                    }
                )
            }
            
            // Quick action buttons
            VStack(spacing: 8) {
                QuickActionButton(
                    icon: "arrow.right.circle",
                    title: "Continue writing",
                    color: .blue
                ) {
                    generateContinuation()
                }
                
                QuickActionButton(
                    icon: "lightbulb",
                    title: "Get ideas",
                    color: .orange
                ) {
                    generateIdeas()
                }
                
                QuickActionButton(
                    icon: "text.quote",
                    title: "Improve style",
                    color: .purple
                ) {
                    improveStyle()
                }
                
                QuickActionButton(
                    icon: "sparkles",
                    title: "Break writer's block",
                    color: .green
                ) {
                    breakWritersBlock()
                }
            }
        }
        .padding(.trailing, 12)
    }
    
    // MARK: - AI Actions
    
    private func generateSuggestion() {
        isThinking = true
        
        // Simulate AI thinking
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                suggestion = "Perhaps you could explore how this experience shaped your perspective on..."
                isThinking = false
            }
        }
    }
    
    private func generateContinuation() {
        isThinking = true
        // Implementation would call AI service
    }
    
    private func generateIdeas() {
        isThinking = true
        // Implementation would call AI service
    }
    
    private func improveStyle() {
        isThinking = true
        // Implementation would call AI service
    }
    
    private func breakWritersBlock() {
        isThinking = true
        // Implementation would call AI service
    }
}

// MARK: - Supporting Views

struct SuggestionCard: View {
    let suggestion: String
    let onAccept: () -> Void
    let onRegenerate: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(suggestion)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 8) {
                Button {
                    onAccept()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .medium))
                        Text("Use")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.green)
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    onRegenerate()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.15 : 0.1),
                    radius: isHovered ? 12 : 8,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 200)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct ThinkingIndicator: View {
    @State private var dots = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .opacity(dots == index ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.3), value: dots)
            }
        }
        .onReceive(timer) { _ in
            dots = (dots + 1) % 3
        }
    }
}

struct BubbleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}