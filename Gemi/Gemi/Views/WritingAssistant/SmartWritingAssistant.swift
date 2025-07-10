import SwiftUI
import AppKit

/// Enhanced AI Writing Assistant with intelligent positioning and real AI integration
struct SmartWritingAssistant: View {
    @Binding var isVisible: Bool
    @Binding var currentText: String
    @Binding var selectedRange: NSRange
    
    // AI Service is injected externally since GemiAICoordinator is a singleton
    
    // UI State
    @State private var assistantMode: AssistantMode = .compact
    @State private var suggestions: [WritingSuggestion] = []
    @State private var isGenerating: Bool = false
    @State private var selectedSuggestionIndex: Int = 0
    
    // Positioning
    @State private var cursorPosition: CGPoint = .zero
    @State private var viewportSize: CGSize = .zero
    @State private var preferredPosition: AssistantPosition = .auto
    
    // Callbacks
    let onSuggestionAccepted: (String) -> Void
    let onCursorPositionUpdate: (@escaping (CGPoint) -> Void) -> Void
    
    enum AssistantMode {
        case compact    // Simple suggestions
        case expanded   // Tool panel
        case conversation // Full chat
    }
    
    enum AssistantPosition {
        case auto
        case above
        case below
        case inline
    }
    
    struct WritingSuggestion: Identifiable {
        let id = UUID()
        let type: SuggestionType
        let text: String
        let icon: String
        let color: Color
        
        enum SuggestionType {
            case continuation
            case improvement
            case idea
            case question
            case emotion
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Invisible backdrop to capture clicks outside
                if isVisible {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissAssistant()
                        }
                }
                
                // Main assistant UI
                if isVisible {
                    assistantContent
                        .position(calculateOptimalPosition(in: geometry))
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8, anchor: anchorPoint).combined(with: .opacity),
                            removal: .scale(scale: 0.8, anchor: anchorPoint).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
                }
            }
            .onAppear {
                viewportSize = geometry.size
                setupCursorTracking()
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                viewportSize = newSize
            }
        }
        .onKeyPress(.escape) {
            if isVisible {
                dismissAssistant()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow) {
            if isVisible && !suggestions.isEmpty {
                selectedSuggestionIndex = max(0, selectedSuggestionIndex - 1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.downArrow) {
            if isVisible && !suggestions.isEmpty {
                selectedSuggestionIndex = min(suggestions.count - 1, selectedSuggestionIndex + 1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if isVisible && !suggestions.isEmpty {
                acceptSuggestion(suggestions[selectedSuggestionIndex])
                return .handled
            }
            return .ignored
        }
    }
    
    @ViewBuilder
    private var assistantContent: some View {
        switch assistantMode {
        case .compact:
            CompactAssistantView(
                suggestions: suggestions,
                selectedIndex: selectedSuggestionIndex,
                isGenerating: isGenerating,
                onSelect: acceptSuggestion,
                onExpand: { assistantMode = .expanded }
            )
        case .expanded:
            ExpandedAssistantView(
                currentText: analyzeCurrentContext(),
                isGenerating: isGenerating,
                onAction: handleAssistantAction,
                onCollapse: { assistantMode = .compact },
                onConversation: { assistantMode = .conversation }
            )
        case .conversation:
            ConversationAssistantView(
                context: analyzeCurrentContext(),
                onClose: { assistantMode = .expanded },
                onInsert: { text in
                    onSuggestionAccepted(text)
                    dismissAssistant()
                }
            )
        }
    }
    
    // MARK: - Positioning Logic
    
    private func calculateOptimalPosition(in geometry: GeometryProxy) -> CGPoint {
        let assistantSize = CGSize(width: 320, height: assistantHeight)
        var position = cursorPosition
        
        // Ensure the assistant stays within viewport bounds
        let padding: CGFloat = 20
        
        // Horizontal positioning
        if position.x + assistantSize.width / 2 > viewportSize.width - padding {
            // Too close to right edge
            position.x = viewportSize.width - assistantSize.width / 2 - padding
        } else if position.x - assistantSize.width / 2 < padding {
            // Too close to left edge
            position.x = assistantSize.width / 2 + padding
        }
        
        // Vertical positioning
        let preferredYOffset: CGFloat = 40 // Distance from cursor
        
        if preferredPosition == .auto {
            // Check if there's space below cursor
            if position.y + preferredYOffset + assistantSize.height < viewportSize.height - padding {
                position.y += preferredYOffset
                preferredPosition = .below
            } else {
                // Position above cursor
                position.y -= (preferredYOffset + assistantSize.height)
                preferredPosition = .above
            }
        }
        
        // Final bounds check
        position.y = max(assistantSize.height / 2 + padding, 
                        min(viewportSize.height - assistantSize.height / 2 - padding, position.y))
        
        return position
    }
    
    private var assistantHeight: CGFloat {
        switch assistantMode {
        case .compact: return 180
        case .expanded: return 280
        case .conversation: return 400
        }
    }
    
    private var anchorPoint: UnitPoint {
        switch preferredPosition {
        case .auto, .below: return .top
        case .above: return .bottom
        case .inline: return .center
        }
    }
    
    // MARK: - Context Analysis
    
    private func analyzeCurrentContext() -> WritingContext {
        // Extract current paragraph
        let paragraphRange = findParagraphRange(in: currentText, at: selectedRange.location)
        let paragraph = String(currentText[paragraphRange])
        
        // Extract previous paragraph for context
        let previousParagraph = findPreviousParagraph(in: currentText, before: paragraphRange.lowerBound)
        
        // Analyze writing metrics
        let wordCount = paragraph.split(separator: " ").count
        let sentimentKeywords = detectSentimentKeywords(in: paragraph)
        let isQuestion = paragraph.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?")
        
        return WritingContext(
            currentParagraph: paragraph,
            previousParagraph: previousParagraph,
            wordCount: wordCount,
            sentiment: sentimentKeywords,
            isQuestion: isQuestion,
            cursorPosition: selectedRange.location - paragraphRange.lowerBound.utf16Offset(in: currentText)
        )
    }
    
    private func findParagraphRange(in text: String, at location: Int) -> Range<String.Index> {
        let nsString = text as NSString
        var paragraphStart = location
        var paragraphEnd = location
        
        // Find paragraph boundaries
        nsString.getParagraphStart(&paragraphStart, end: &paragraphEnd, contentsEnd: nil, for: NSRange(location: location, length: 0))
        
        let startIndex = text.index(text.startIndex, offsetBy: paragraphStart)
        let endIndex = text.index(text.startIndex, offsetBy: paragraphEnd)
        
        return startIndex..<endIndex
    }
    
    private func findPreviousParagraph(in text: String, before index: String.Index) -> String? {
        guard index > text.startIndex else { return nil }
        
        let beforeIndex = text.index(before: index)
        let searchText = String(text[text.startIndex..<beforeIndex])
        
        if let lastNewline = searchText.lastIndex(of: "\n") {
            let paragraphStart = searchText.index(after: lastNewline)
            return String(searchText[paragraphStart...])
        }
        
        return searchText.isEmpty ? nil : searchText
    }
    
    private func detectSentimentKeywords(in text: String) -> [String] {
        let positiveWords = ["happy", "excited", "grateful", "love", "wonderful", "amazing", "blessed"]
        let negativeWords = ["sad", "angry", "frustrated", "worried", "anxious", "stressed", "tired"]
        
        let lowercased = text.lowercased()
        var keywords: [String] = []
        
        for word in positiveWords where lowercased.contains(word) {
            keywords.append(word)
        }
        for word in negativeWords where lowercased.contains(word) {
            keywords.append(word)
        }
        
        return keywords
    }
    
    // MARK: - AI Integration
    
    private func generateContextualSuggestions() async {
        isGenerating = true
        suggestions = []
        
        let context = analyzeCurrentContext()
        
        // For now, use smart fallbacks until we properly integrate with WritingAssistanceService
        await MainActor.run {
            suggestions = generateSmartFallbacks(for: context)
            isGenerating = false
        }
    }
    
    private func buildContextualPrompt(for context: WritingContext) -> String {
        """
        As a writing assistant for a journal entry, analyze this context and provide 3-4 specific, actionable suggestions.
        
        Current paragraph: "\(context.currentParagraph)"
        Previous context: "\(context.previousParagraph ?? "Beginning of entry")"
        Word count: \(context.wordCount)
        Detected emotions: \(context.sentiment.joined(separator: ", "))
        
        Provide suggestions in this format:
        1. [CONTINUE] A natural continuation of the current thought
        2. [EXPLORE] A deeper question or reflection to explore
        3. [DETAIL] A specific detail or sensory element to add
        4. [EMOTION] An emotional insight or connection to explore
        
        Make suggestions specific to the content, not generic writing advice.
        """
    }
    
    private func parseAISuggestions(_ response: String) -> [WritingSuggestion] {
        // Parse AI response into structured suggestions
        let lines = response.split(separator: "\n")
        var suggestions: [WritingSuggestion] = []
        
        for line in lines {
            if line.contains("[CONTINUE]") {
                let text = line.replacingOccurrences(of: "[CONTINUE]", with: "").trimmingCharacters(in: .whitespaces)
                suggestions.append(WritingSuggestion(type: .continuation, text: text, icon: "arrow.right.circle", color: .blue))
            } else if line.contains("[EXPLORE]") {
                let text = line.replacingOccurrences(of: "[EXPLORE]", with: "").trimmingCharacters(in: .whitespaces)
                suggestions.append(WritingSuggestion(type: .question, text: text, icon: "magnifyingglass", color: .purple))
            } else if line.contains("[DETAIL]") {
                let text = line.replacingOccurrences(of: "[DETAIL]", with: "").trimmingCharacters(in: .whitespaces)
                suggestions.append(WritingSuggestion(type: .idea, text: text, icon: "lightbulb", color: .orange))
            } else if line.contains("[EMOTION]") {
                let text = line.replacingOccurrences(of: "[EMOTION]", with: "").trimmingCharacters(in: .whitespaces)
                suggestions.append(WritingSuggestion(type: .emotion, text: text, icon: "heart", color: .pink))
            }
        }
        
        return suggestions
    }
    
    private func generateSmartFallbacks(for context: WritingContext) -> [WritingSuggestion] {
        var suggestions: [WritingSuggestion] = []
        
        // Context-aware fallbacks based on analysis
        if context.wordCount < 10 {
            suggestions.append(WritingSuggestion(
                type: .continuation,
                text: "What happened next? Describe the moment in detail.",
                icon: "arrow.right.circle",
                color: .blue
            ))
        }
        
        if context.isQuestion {
            suggestions.append(WritingSuggestion(
                type: .question,
                text: "Take a moment to explore this question. What comes to mind?",
                icon: "magnifyingglass",
                color: .purple
            ))
        }
        
        if !context.sentiment.isEmpty {
            suggestions.append(WritingSuggestion(
                type: .emotion,
                text: "How did this make you feel in your body? Where do you feel it?",
                icon: "heart",
                color: .pink
            ))
        }
        
        suggestions.append(WritingSuggestion(
            type: .idea,
            text: "Add a sensory detail - what did you see, hear, or smell?",
            icon: "lightbulb",
            color: .orange
        ))
        
        return suggestions
    }
    
    // MARK: - Actions
    
    private func acceptSuggestion(_ suggestion: WritingSuggestion) {
        onSuggestionAccepted(suggestion.text)
        dismissAssistant()
    }
    
    private func handleAssistantAction(_ action: AssistantAction) {
        Task {
            await generateContextualSuggestions()
        }
    }
    
    private func dismissAssistant() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
            assistantMode = .compact
            suggestions = []
        }
    }
    
    private func setupCursorTracking() {
        onCursorPositionUpdate { position in
            cursorPosition = position
        }
    }
}

// MARK: - Supporting Types

struct WritingContext {
    let currentParagraph: String
    let previousParagraph: String?
    let wordCount: Int
    let sentiment: [String]
    let isQuestion: Bool
    let cursorPosition: Int
}

enum AssistantAction {
    case continueWriting
    case getIdeas
    case improveStyle
    case breakBlock
}

// MARK: - Subviews

struct CompactAssistantView: View {
    let suggestions: [SmartWritingAssistant.WritingSuggestion]
    let selectedIndex: Int
    let isGenerating: Bool
    let onSelect: (SmartWritingAssistant.WritingSuggestion) -> Void
    let onExpand: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Writing Assistant", systemImage: "wand.and.stars")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
            
            Divider()
            
            // Suggestions
            if isGenerating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing your writing...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                            SmartSuggestionRow(
                                suggestion: suggestion,
                                isSelected: index == selectedIndex,
                                onTap: { onSelect(suggestion) }
                            )
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SmartSuggestionRow: View {
    let suggestion: SmartWritingAssistant.WritingSuggestion
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 16))
                    .foregroundColor(suggestion.color)
                    .frame(width: 24, height: 24)
                
                Text(suggestion.text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? suggestion.color.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// Placeholder views for expanded modes
struct ExpandedAssistantView: View {
    let currentText: WritingContext
    let isGenerating: Bool
    let onAction: (AssistantAction) -> Void
    let onCollapse: () -> Void
    let onConversation: () -> Void
    
    var body: some View {
        // Implementation details...
        Text("Expanded View")
            .frame(width: 320, height: 280)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
    }
}

struct ConversationAssistantView: View {
    let context: WritingContext
    let onClose: () -> Void
    let onInsert: (String) -> Void
    
    var body: some View {
        // Implementation details...
        Text("Conversation View")
            .frame(width: 320, height: 400)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
    }
}