import SwiftUI

/// Enhanced message row with markdown support and animations
struct EnhancedMessageRow: View {
    let message: ChatHistoryMessage
    let isStreaming: Bool
    @State private var isHovered = false
    @State private var showTimestamp = false
    @State private var isCopied = false
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacing) {
            // Avatar
            if message.role == .assistant {
                AvatarView(role: message.role)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Spacer()
                    .frame(width: 40)
            }
            
            // Message content
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message bubble
                VStack(alignment: .leading, spacing: 0) {
                    if message.role == .assistant {
                        messageContent
                    } else {
                        Text(message.content)
                            .font(Theme.Typography.body)
                    }
                }
                .padding(Theme.spacing)
                .background(messageBubbleBackground)
                .foregroundColor(message.role == .user ? .white : Color.primary)
                .cornerRadius(Theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .strokeBorder(
                            message.role == .assistant ? Theme.Colors.divider : Color.clear,
                            lineWidth: 1
                        )
                )
                .contextMenu {
                    messageContextMenu
                }
                
                // Timestamp and actions
                HStack(spacing: Theme.smallSpacing) {
                    if showTimestamp || isHovered {
                        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                            .transition(.opacity)
                    }
                    
                    if isHovered && message.role == .assistant {
                        messageActions
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
            .frame(maxWidth: 600, alignment: message.role == .user ? .trailing : .leading)
            
            // Right spacing
            if message.role == .user {
                AvatarView(role: message.role)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Spacer()
                    .frame(width: 40)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            showTimestamp.toggle()
        }
    }
    
    @ViewBuilder
    private var messageContent: some View {
        if isStreaming {
            HStack(alignment: .bottom, spacing: 2) {
                FormattedText(content: message.content)
                
                BlinkingCursor()
            }
        } else {
            FormattedText(content: message.content)
        }
    }
    
    private var messageBubbleBackground: some View {
        Group {
            if message.role == .user {
                LinearGradient(
                    colors: [Theme.Colors.primaryAccent, Theme.Colors.primaryAccent.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Theme.Colors.cardBackground
            }
        }
    }
    
    private var messageActions: some View {
        HStack(spacing: Theme.smallSpacing) {
            ActionButton(icon: "doc.on.doc", tooltip: isCopied ? "Copied!" : "Copy") {
                copyMessage()
            }
            
            ActionButton(icon: "arrow.clockwise", tooltip: "Regenerate") {
                // TODO: Implement regenerate
            }
            
            ActionButton(icon: "hand.thumbsup", tooltip: "Good response") {
                // TODO: Implement feedback
            }
            
            ActionButton(icon: "hand.thumbsdown", tooltip: "Poor response") {
                // TODO: Implement feedback
            }
        }
    }
    
    private var messageContextMenu: some View {
        Group {
            Button("Copy") {
                copyMessage()
            }
            
            if message.role == .assistant {
                Divider()
                
                Button("Regenerate Response") {
                    // TODO: Implement regenerate
                }
                
                Button("Report Issue") {
                    // TODO: Implement report
                }
            }
        }
    }
    
    private func copyMessage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        
        withAnimation {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

// MARK: - Supporting Views

struct AvatarView: View {
    let role: ChatHistoryMessage.MessageRole
    
    var body: some View {
        ZStack {
            Circle()
                .fill(avatarBackground)
                .frame(width: 32, height: 32)
            
            Image(systemName: avatarIcon)
                .font(.system(size: 16))
                .foregroundColor(avatarForeground)
        }
    }
    
    private var avatarBackground: Color {
        switch role {
        case .user:
            return Theme.Colors.primaryAccent.opacity(0.2)
        case .assistant:
            return LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).asColor()
        case .system:
            return Color.gray.opacity(0.2)
        }
    }
    
    private var avatarForeground: Color {
        switch role {
        case .user:
            return Theme.Colors.primaryAccent
        case .assistant:
            return .purple
        case .system:
            return .gray
        }
    }
    
    private var avatarIcon: String {
        switch role {
        case .user:
            return "person.fill"
        case .assistant:
            return "sparkles"
        case .system:
            return "gear"
        }
    }
}

struct ActionButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isHovered ? Theme.Colors.primaryAccent : Theme.Colors.secondaryText)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isHovered ? Theme.Colors.primaryAccent.opacity(0.1) : Color.clear)
                )
                .scaleEffect(isHovered ? 1.1 : 1)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct BlinkingCursor: View {
    @State private var isVisible = true
    
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.primaryAccent)
            .frame(width: 2, height: 16)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                ) {
                    isVisible = false
                }
            }
    }
}

// MARK: - Formatted Text View

struct FormattedText: View {
    let content: String
    
    var body: some View {
        Text(formattedAttributedString)
            .font(Theme.Typography.body)
            .textSelection(.enabled)
    }
    
    private var formattedAttributedString: AttributedString {
        var attributedString = AttributedString(content)
        
        // Basic markdown-like formatting
        // Bold: **text**
        if let regex = try? NSRegularExpression(pattern: "\\*\\*(.*?)\\*\\*", options: []) {
            let nsString = content as NSString
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 2 {
                    let range = match.range(at: 1)
                    if let swiftRange = Range(range, in: content) {
                        if let attrRange = attributedString.range(of: String(content[swiftRange])) {
                            attributedString[attrRange].inlinePresentationIntent = .stronglyEmphasized
                        }
                    }
                }
            }
        }
        
        // Code: `text`
        if let regex = try? NSRegularExpression(pattern: "`(.*?)`", options: []) {
            let nsString = content as NSString
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 2 {
                    let range = match.range(at: 1)
                    if let swiftRange = Range(range, in: content) {
                        if let attrRange = attributedString.range(of: String(content[swiftRange])) {
                            attributedString[attrRange].inlinePresentationIntent = .code
                            attributedString[attrRange].backgroundColor = Theme.Colors.cardBackground
                        }
                    }
                }
            }
        }
        
        return attributedString
    }
}

// MARK: - Extensions

extension LinearGradient {
    func asColor() -> Color {
        // For preview purposes, return the first color
        return Color.purple.opacity(0.3)
    }
}