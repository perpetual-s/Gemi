import SwiftUI

/// Enhanced message bubble with premium streaming effects
struct StreamingMessageBubble: View {
    let message: ChatHistoryMessage
    let isStreaming: Bool
    @State private var isHovered = false
    @State private var typingPhase = 0
    @State private var shimmerOffset: CGFloat = -1
    @State private var cursorOpacity = 1.0
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                // Assistant avatar with pulse animation
                AssistantAvatar(isActive: isStreaming)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Images if present
                if let images = message.images, !images.isEmpty {
                    ImageGallery(images: images)
                }
                
                // Message content with streaming effects
                messageContent
                    .background(bubbleBackground)
                    .cornerRadius(20)
                    .shadow(
                        color: message.role == .user 
                            ? Theme.Colors.primaryAccent.opacity(0.2)
                            : Color.purple.opacity(isStreaming ? 0.3 : 0.1),
                        radius: isStreaming ? 15 : 8,
                        y: 4
                    )
                    .scaleEffect(isStreaming && message.content.isEmpty ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3), value: isStreaming)
                
                // Timestamp with smooth transition
                if isHovered && !isStreaming {
                    timestamp
                }
            }
            .frame(maxWidth: 500, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .user {
                // User avatar
                UserAvatar()
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .onHover { hovering in
            if !isStreaming {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
        }
        .onAppear {
            if isStreaming {
                startStreamingAnimations()
            }
        }
    }
    
    @ViewBuilder
    private var messageContent: some View {
        ZStack(alignment: .topLeading) {
            if isStreaming && message.content.isEmpty {
                // Typing indicator for empty streaming messages
                StreamingTypingIndicator()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                // Message text with optional streaming cursor
                HStack(spacing: 0) {
                    Text(message.content)
                        .font(Theme.Typography.body)
                        .foregroundColor(message.role == .user ? .white : .primary)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if isStreaming && message.role == .assistant {
                        // Blinking cursor
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: 2, height: 18)
                            .opacity(cursorOpacity)
                            .animation(
                                .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true),
                                value: cursorOpacity
                            )
                            .onAppear {
                                cursorOpacity = 0
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Shimmer effect overlay for streaming
                if isStreaming && message.role == .assistant {
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.1),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 100)
                        .offset(x: shimmerOffset * (geometry.size.width + 100))
                        .animation(
                            .linear(duration: 2)
                            .repeatForever(autoreverses: false),
                            value: shimmerOffset
                        )
                        .onAppear {
                            shimmerOffset = 1
                        }
                    }
                    .mask(
                        RoundedRectangle(cornerRadius: 20)
                    )
                    .allowsHitTesting(false)
                }
            }
        }
    }
    
    private var timestamp: some View {
        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
            .font(Theme.Typography.footnote)
            .foregroundColor(Theme.Colors.tertiaryText)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
    }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
            LinearGradient(
                colors: [
                    Theme.Colors.primaryAccent,
                    Theme.Colors.primaryAccent.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Assistant bubble with animated gradient when streaming
            if isStreaming {
                AnimatedGradient()
            } else {
                Color(NSColor.controlBackgroundColor)
            }
        }
    }
    
    private func startStreamingAnimations() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
            typingPhase = 3
        }
    }
}

// MARK: - Supporting Views

struct AssistantAvatar: View {
    let isActive: Bool
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            if isActive {
                // Pulsing background
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .scaleEffect(pulse ? 1.3 : 1.0)
                    .opacity(pulse ? 0 : 0.5)
                    .animation(
                        .easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: pulse
                    )
            }
            
            Circle()
                .fill(Color.purple.opacity(0.1))
                .frame(width: 32, height: 32)
            
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.variableColor.iterative, value: isActive)
        }
        .onAppear {
            if isActive {
                pulse = true
            }
        }
    }
}

struct UserAvatar: View {
    var body: some View {
        Circle()
            .fill(Theme.Colors.primaryAccent.opacity(0.1))
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.Colors.primaryAccent)
            )
    }
}

struct ImageGallery: View {
    let images: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(images, id: \.self) { base64Image in
                    if let data = Data(base64Encoded: base64Image),
                       let image = NSImage(data: data) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    }
                }
            }
        }
        .frame(maxWidth: 400)
    }
}

struct StreamingTypingIndicator: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.purple.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.3 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            animationPhase = -1
        }
    }
}

struct AnimatedGradient: View {
    @State private var animate = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.purple.opacity(0.05),
                Color.blue.opacity(0.05),
                Color.purple.opacity(0.05)
            ],
            startPoint: animate ? .topLeading : .bottomTrailing,
            endPoint: animate ? .bottomTrailing : .topLeading
        )
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}