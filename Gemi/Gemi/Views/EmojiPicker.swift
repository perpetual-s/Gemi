import SwiftUI
import AppKit

/// A production-quality emoji picker for macOS
struct EmojiPicker: View {
    @Binding var selectedEmoji: String?
    @Binding var isPresented: Bool
    let onEmojiSelected: (String) -> Void
    
    @State private var searchText = ""
    @State private var selectedCategory = EmojiCategory.smileys
    
    let columns = Array(repeating: GridItem(.fixed(36), spacing: 8), count: 9)
    
    var filteredEmojis: [String] {
        let emojis = selectedCategory.emojis
        if searchText.isEmpty {
            return emojis
        } else {
            return emojis.filter { emoji in
                selectedCategory.searchableTerms(for: emoji)
                    .contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 0) {
                HStack {
                    Text("Emoji Picker")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search emojis", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(EmojiCategory.allCases, id: \.self) { category in
                            CategoryTab(
                                category: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
                
                Divider()
            }
            .background(ProductionVisualEffectView())
            
            // Emoji grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(filteredEmojis, id: \.self) { emoji in
                        EmojiButton(
                            emoji: emoji,
                            action: {
                                selectedEmoji = emoji
                                onEmojiSelected(emoji)
                                isPresented = false
                            }
                        )
                    }
                }
                .padding(16)
            }
            .frame(height: 320)
        }
        .frame(width: 400, height: 480)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Emoji Category

enum EmojiCategory: String, CaseIterable {
    case smileys = "Smileys"
    case nature = "Nature"
    case food = "Food"
    case activities = "Activities"
    case travel = "Travel"
    case objects = "Objects"
    case symbols = "Symbols"
    case flags = "Flags"
    
    var icon: String {
        switch self {
        case .smileys: return "😀"
        case .nature: return "🌿"
        case .food: return "🍔"
        case .activities: return "⚽"
        case .travel: return "✈️"
        case .objects: return "💡"
        case .symbols: return "❤️"
        case .flags: return "🏁"
        }
    }
    
    var emojis: [String] {
        switch self {
        case .smileys:
            return ["😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", 
                    "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "☺️", "😚", 
                    "😙", "🥲", "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", 
                    "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶", "😏", "😒", "🙄", 
                    "😬", "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕"]
        case .nature:
            return ["🌿", "🌱", "🍀", "🌾", "🌳", "🌴", "🌵", "🌷", "🌹", "🥀", 
                    "🌺", "🌸", "🌼", "🌻", "🌞", "🌝", "🌛", "🌜", "🌚", "🌕", 
                    "🌖", "🌗", "🌘", "🌑", "🌒", "🌓", "🌔", "⭐", "🌟", "✨", 
                    "⚡", "☄️", "💥", "🔥", "🌈", "☀️", "🌤", "⛅", "🌥", "☁️", 
                    "🌦", "🌧", "⛈", "🌩", "🌨", "❄️", "☃️", "⛄", "🌬", "💨"]
        case .food:
            return ["🍎", "🍏", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", 
                    "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", 
                    "🥬", "🥒", "🌶", "🫑", "🌽", "🥕", "🥔", "🍠", "🥐", "🥖", 
                    "🥨", "🧀", "🥚", "🍳", "🥓", "🥩", "🍗", "🍖", "🌭", "🍔", 
                    "🍟", "🍕", "🥪", "🌮", "🌯", "🫔", "🥗", "🥘", "🍝", "🍜"]
        case .activities:
            return ["⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", 
                    "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏", "🪃", "🥅", "⛳", 
                    "🪁", "🏹", "🎣", "🤿", "🥊", "🥋", "🎽", "🛹", "🛼", "🛷", 
                    "⛸", "🥌", "🎿", "⛷", "🏂", "🪂", "🏋️", "🤼", "🤸", "⛹️", 
                    "🤺", "🤾", "🏌️", "🏇", "🧘", "🏄", "🏊", "🤽", "🚣", "🧗"]
        case .travel:
            return ["✈️", "🛫", "🛬", "🪂", "💺", "🚁", "🚟", "🚠", "🚡", "🛰", 
                    "🚀", "🛸", "🚂", "🚆", "🚄", "🚅", "🚈", "🚇", "🚝", "🚞", 
                    "🚋", "🚃", "🚊", "🚉", "🚗", "🚕", "🚙", "🚌", "🚎", "🏎", 
                    "🚓", "🚑", "🚒", "🚐", "🛻", "🚚", "🚛", "🚜", "🏍", "🛵", 
                    "🚲", "🛴", "🛹", "🛼", "🚏", "🛣", "⛽", "🚨", "🚥", "🚦"]
        case .objects:
            return ["💡", "🔦", "🏮", "🪔", "📱", "💻", "🖥", "🖨", "⌨️", "🖱", 
                    "🖲", "💾", "💿", "📀", "📼", "📷", "📸", "📹", "🎥", "📽", 
                    "🎞", "📞", "☎️", "📟", "📠", "📺", "📻", "🎙", "🎚", "🎛", 
                    "🧭", "⏱", "⏲", "⏰", "🕰", "⌛", "⏳", "📡", "🔋", "🔌", 
                    "💰", "💴", "💵", "💶", "💷", "🪙", "💳", "💎", "⚖️", "🪜"]
        case .symbols:
            return ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", 
                    "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️", 
                    "✝️", "☪️", "🕉", "☸️", "✡️", "🔯", "🕎", "☯️", "☦️", "🛐", 
                    "♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", 
                    "♒", "♓", "⚛️", "🉑", "☢️", "☣️", "📴", "📳", "🈶", "🈚"]
        case .flags:
            return ["🏁", "🚩", "🎌", "🏴", "🏳️", "🏳️‍🌈", "🏳️‍⚧️", "🏴‍☠️", "🇦🇨", "🇦🇩", 
                    "🇦🇪", "🇦🇫", "🇦🇬", "🇦🇮", "🇦🇱", "🇦🇲", "🇦🇴", "🇦🇶", "🇦🇷", "🇦🇸", 
                    "🇦🇹", "🇦🇺", "🇦🇼", "🇦🇽", "🇦🇿", "🇧🇦", "🇧🇧", "🇧🇩", "🇧🇪", "🇧🇫", 
                    "🇧🇬", "🇧🇭", "🇧🇮", "🇧🇯", "🇧🇱", "🇧🇲", "🇧🇳", "🇧🇴", "🇧🇶", "🇧🇷", 
                    "🇧🇸", "🇧🇹", "🇧🇻", "🇧🇼", "🇧🇾", "🇧🇿", "🇨🇦", "🇨🇨", "🇨🇩", "🇨🇫"]
        }
    }
    
    func searchableTerms(for emoji: String) -> [String] {
        // This would ideally use a comprehensive emoji database
        // For now, return basic terms
        return [emoji, self.rawValue.lowercased()]
    }
}

// MARK: - Supporting Views

struct CategoryTab: View {
    let category: EmojiCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(category.icon)
                    .font(.system(size: 20))
                Text(category.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct EmojiButton: View {
    let emoji: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(emoji)
                .font(.system(size: 24))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
                )
                .scaleEffect(isHovered ? 1.2 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - NSTextView Extension

extension NSTextView {
    func insertEmoji(_ emoji: String) {
        guard let textStorage = self.textStorage else { return }
        
        let selectedRange = self.selectedRange()
        textStorage.replaceCharacters(in: selectedRange, with: emoji)
        
        // Move cursor after inserted emoji
        self.setSelectedRange(NSRange(location: selectedRange.location + emoji.count, length: 0))
    }
}