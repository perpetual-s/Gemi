import SwiftUI

/// Premium entry card with hover effects and smooth animations
struct PremiumEntryCard: View {
    let entry: JournalEntry
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onChat: () -> Void
    
    @State private var isHovered = false
    @State private var showingActions = false
    @State private var deleteConfirmation = false
    
    private var moodGradient: LinearGradient {
        if let mood = entry.mood {
            let colors = moodColors(for: mood)
            return LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func moodColors(for mood: Mood) -> [Color] {
        switch mood {
        case .happy: return [.yellow.opacity(0.3), .orange.opacity(0.2)]
        case .sad: return [.blue.opacity(0.3), .indigo.opacity(0.2)]
        case .neutral: return [.gray.opacity(0.2), .gray.opacity(0.1)]
        case .excited: return [.pink.opacity(0.3), .purple.opacity(0.2)]
        case .anxious: return [.orange.opacity(0.3), .red.opacity(0.2)]
        case .peaceful: return [.green.opacity(0.3), .teal.opacity(0.2)]
        case .grateful: return [.purple.opacity(0.3), .pink.opacity(0.2)]
        case .accomplished: return [.blue.opacity(0.3), .cyan.opacity(0.2)]
        case .frustrated: return [.red.opacity(0.3), .orange.opacity(0.2)]
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                // Main card content
                cardContent
                
                // Favorite indicator
                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                        .padding(12)
                        .shadow(color: .yellow.opacity(0.5), radius: 4)
                }
            }
        }
        .buttonStyle(EnhancedCardButtonStyle(isSelected: isSelected, isHovered: isHovered))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
                showingActions = hovering
            }
        }
        .contextMenu {
            contextMenuContent
        }
        .confirmationDialog("Delete Entry", isPresented: $deleteConfirmation) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
    }
    
    private var cardContent: some View {
        HStack(alignment: .top, spacing: 16) {
            // Mood indicator strip
            RoundedRectangle(cornerRadius: 4)
                .fill(moodGradient)
                .frame(width: 4)
                .opacity(isHovered ? 1 : 0.7)
            
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.displayTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        HStack(spacing: 12) {
                            // Time
                            Label {
                                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                            } icon: {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            
                            // Word count
                            Label {
                                Text("\(entry.wordCount) words")
                            } icon: {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 11))
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            
                            // Mood
                            if let mood = entry.mood {
                                Text(mood.emoji)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Quick actions (visible on hover)
                    if showingActions {
                        quickActionsMenu
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Preview text
                Text(entry.preview)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .lineSpacing(2)
                
                // Tags
                if !entry.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(entry.tags, id: \.self) { tag in
                                TagChip(tag: tag)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .padding()
    }
    
    private var quickActionsMenu: some View {
        HStack(spacing: 4) {
            ActionButton(icon: "square.and.pencil", action: onEdit, tooltip: "Edit")
            ActionButton(icon: "bubble.left", action: onChat, tooltip: "Chat")
            ActionButton(icon: "trash", action: { deleteConfirmation = true }, tooltip: "Delete", isDestructive: true)
        }
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            onEdit()
        } label: {
            Label("Edit", systemImage: "square.and.pencil")
        }
        
        Button {
            onChat()
        } label: {
            Label("Chat about this", systemImage: "bubble.left")
        }
        
        Divider()
        
        Button {
            // Copy to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.content, forType: .string)
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(role: .destructive) {
            deleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Supporting Views

struct EnhancedCardButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isHovered: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                ZStack {
                    // Base layer with glass effect
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                    
                    // Subtle glass overlay
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.08 : 0.04),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Ambient glow on hover
                    if isHovered {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.Colors.primaryAccent.opacity(0.03))
                    }
                }
            )
            .shadow(
                color: isSelected ? Theme.Colors.primaryAccent.opacity(0.2) : Color.black.opacity(isHovered ? 0.1 : 0.05),
                radius: isHovered ? 12 : 8,
                x: 0,
                y: isHovered ? 4 : 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Theme.Colors.primaryAccent : (isHovered ? Color.white.opacity(0.1) : Color.clear),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .animation(Theme.microInteraction, value: configuration.isPressed)
            .animation(Theme.gentleSpring, value: isHovered)
    }
}

struct CardButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isHovered: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(
                        color: .black.opacity(isHovered ? 0.1 : 0.05),
                        radius: isHovered ? 12 : 8,
                        x: 0,
                        y: isHovered ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

struct ActionButton: View {
    let icon: String
    let action: () -> Void
    let tooltip: String
    var isDestructive: Bool = false
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isDestructive ? .red : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .help(tooltip)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct TagChip: View {
    let tag: String
    
    var body: some View {
        Text("#\(tag)")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.1))
            )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        PremiumEntryCard(
            entry: JournalEntry(
                title: "A Beautiful Day",
                content: "Today was absolutely wonderful. The sun was shining, birds were singing, and I felt a deep sense of gratitude for all the little things in life.",
                tags: ["gratitude", "nature", "happiness"],
                mood: .grateful,
                isFavorite: true
            ),
            isSelected: false,
            onSelect: {},
            onEdit: {},
            onDelete: {},
            onChat: {}
        )
        
        PremiumEntryCard(
            entry: JournalEntry(
                title: "Reflections on Growth",
                content: "I've been thinking about how much I've changed over the past year. The challenges I faced taught me resilience.",
                tags: ["reflection", "growth"],
                mood: .peaceful
            ),
            isSelected: true,
            onSelect: {},
            onEdit: {},
            onDelete: {},
            onChat: {}
        )
    }
    .padding()
    .frame(width: 600)
}