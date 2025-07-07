import SwiftUI

/// Lightweight emoji picker for quick selection
struct QuickEmojiPicker: View {
    let onEmojiSelected: (String) -> Void
    @Binding var isPresented: Bool
    
    // Common emojis for journaling
    let quickEmojis = [
        "😊", "😢", "😭", "😄", "😍", "🥰", "😔", "😌", "😴",
        "😤", "😡", "😰", "😨", "🤔", "💭", "💡", "❤️", "💔",
        "🌟", "✨", "🎉", "🎯", "💪", "🙏", "👍", "👎", "🤗",
        "📝", "📖", "☕", "🌙", "☀️", "🌈", "🌺", "🍃", "🎵"
    ]
    
    let columns = Array(repeating: GridItem(.fixed(44), spacing: 8), count: 6)
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Choose an emoji")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(quickEmojis, id: \.self) { emoji in
                    Button {
                        onEmojiSelected(emoji)
                        isPresented = false
                    } label: {
                        Text(emoji)
                            .font(.system(size: 24))
                            .frame(width: 40, height: 40)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(1.0)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 320)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}

