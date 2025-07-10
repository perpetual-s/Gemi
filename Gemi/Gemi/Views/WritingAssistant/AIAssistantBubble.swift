import SwiftUI
import Combine

/// Enhanced AI assistant bubble with intelligent positioning and real AI integration
struct AIAssistantBubble: View {
    @Binding var isVisible: Bool
    @Binding var isExpanded: Bool
    @Binding var currentText: String
    @Binding var selectedRange: NSRange
    
    @StateObject private var writingService = WritingAssistanceService()
    @State private var suggestions: [Suggestion] = []
    @State private var isThinking: Bool = false
    @State private var bubbleOpacity: Double = 0
    @State private var scale: Double = 0.8
    @State private var dragOffset: CGSize = .zero
    @State private var position: CGPoint = .zero
    @State private var currentTab: AssistantTab = .tools
    @State private var writingPrompts: [WritingPrompt] = []
    @State private var selectedPromptCategory: PromptCategory = .inspiration
    let onSuggestionAccepted: (String) -> Void
    let editorBounds: CGRect
    
    enum AssistantTab {
        case tools
        case ideas
    }
    
    struct WritingPrompt: Identifiable {
        let id = UUID()
        let text: String
        let category: PromptCategory
    }
    
    enum PromptCategory: String, CaseIterable {
        case inspiration = "Inspiration"
        case memory = "Memory"
        case sensory = "Sensory"
        case whatIf = "What If"
        
        var icon: String {
            switch self {
            case .inspiration: return "sparkles"
            case .memory: return "clock.arrow.circlepath"
            case .sensory: return "eye"
            case .whatIf: return "questionmark.bubble"
            }
        }
        
        var color: Color {
            switch self {
            case .inspiration: return .purple
            case .memory: return .orange
            case .sensory: return .pink
            case .whatIf: return .green
            }
        }
    }
    
    struct Suggestion: Identifiable {
        let id = UUID()
        let text: String
        let type: SuggestionType
        let icon: String
        let color: Color
        
        enum SuggestionType {
            case continuation
            case idea
            case style
            case emotion
            case question
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 12) {
                // Main bubble button
                bubbleButton
                
                if isExpanded {
                    expandedContent
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8, anchor: .leading).combined(with: .opacity),
                            removal: .scale(scale: 0.8, anchor: .leading).combined(with: .opacity)
                        ))
                }
            }
            .position(calculateOptimalPosition(in: geometry))
            .offset(dragOffset)
            .opacity(bubbleOpacity)
            .scaleEffect(scale)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scale)
            .animation(.easeOut(duration: 0.3), value: bubbleOpacity)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isExpanded {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { _ in
                        // Keep the dragged position
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            updatePosition()
            animateIn()
        }
        .onChange(of: selectedRange) { oldRange, newRange in
            if !dragOffset.isZero { return } // Don't update if user has dragged
            updatePosition()
        }
        .onKeyPress(.escape) {
            if isExpanded {
                withAnimation {
                    isExpanded = false
                }
                return .handled
            }
            return .ignored
        }
    }
    
    private var bubbleButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
            }
        } label: {
            ZStack {
                // Glass morphism background matching sidebar style
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.Colors.primaryAccent.opacity(0.15),
                                        Theme.Colors.primaryAccent.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                
                // Subtle border and shadow
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Icon with animation
                if isThinking {
                    ThinkingIndicator()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: isExpanded ? "xmark" : "wand.and.stars")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Theme.Colors.primaryAccent)
                        .symbolEffect(.pulse, value: !isExpanded && suggestions.isEmpty)
                }
            }
        }
        .buttonStyle(BubbleButtonStyle())
        .help("AI Writing Assistant")
    }
    
    private var expandedContent: some View {
        VStack(spacing: 0) {
            // Minimal header with tab navigation
            HStack(spacing: 16) {
                AssistantTabButton(title: "Tools", icon: "wand.and.stars", isSelected: currentTab == .tools) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentTab = .tools
                        suggestions = []
                    }
                }
                
                AssistantTabButton(title: "Ideas", icon: "lightbulb", isSelected: currentTab == .ideas) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentTab = .ideas
                        loadWritingPrompts()
                    }
                }
                
                Spacer()
                
                if isThinking {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Content based on current tab
            Group {
                if currentTab == .tools {
                    toolsContent
                } else {
                    ideasContent
                }
            }
        }
        .frame(width: 340, height: calculatePanelHeight())
        .background(
            ZStack {
                // Glass morphism background
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(NSColor.controlBackgroundColor).opacity(0.2),
                                Color(NSColor.controlBackgroundColor).opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private var toolsContent: some View {
        VStack(spacing: 0) {
            if !suggestions.isEmpty {
                ScrollView {
                    // Show suggestions with refined design
                    VStack(spacing: 2) {
                        ForEach(suggestions) { suggestion in
                            RefinedSuggestionRow(
                                suggestion: suggestion,
                                onTap: {
                                    onSuggestionAccepted(suggestion.text)
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        suggestions = []
                                        isExpanded = false
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            } else {
                    // Integrated action buttons without boxes
                    VStack(alignment: .leading, spacing: 0) {
                        ActionItem(
                            icon: "arrow.right.circle",
                            title: "Continue writing",
                            subtitle: "Let AI complete your thought",
                            color: .blue
                        ) {
                            Task { await generateContinuation() }
                        }
                        
                        ActionItem(
                            icon: "lightbulb",
                            title: "Get ideas",
                            subtitle: "Explore new directions",
                            color: .orange
                        ) {
                            Task { await generateIdeas() }
                        }
                        
                        ActionItem(
                            icon: "text.quote",
                            title: "Improve style",
                            subtitle: "Enhance your writing voice",
                            color: .purple
                        ) {
                            Task { await improveStyle() }
                        }
                        
                        ActionItem(
                            icon: "sparkles",
                            title: "Break writer's block",
                            subtitle: "Switch to Ideas tab for prompts",
                            color: .green
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentTab = .ideas
                                loadWritingPrompts()
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 8)
            }
        }
    }
    
    private var ideasContent: some View {
        VStack(spacing: 0) {
            // Category selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PromptCategory.allCases, id: \.self) { category in
                        CategoryPill(
                            category: category,
                            isSelected: selectedPromptCategory == category
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPromptCategory = category
                                loadWritingPrompts()
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            Divider()
                .opacity(0.5)
            
            // Writing prompts
            if writingPrompts.isEmpty && isThinking {
                Spacer()
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating prompts...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(writingPrompts) { prompt in
                            WritingPromptCard(prompt: prompt) {
                                onSuggestionAccepted(prompt.text)
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isExpanded = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
    
    // MARK: - Positioning
    
    private func calculateOptimalPosition(in geometry: GeometryProxy) -> CGPoint {
        let bubbleSize = CGSize(width: 56, height: 56)
        let expandedWidth: CGFloat = isExpanded ? 320 : 0
        
        // Position in the middle-right area of the window
        let windowWidth = geometry.size.width
        let windowHeight = geometry.size.height
        
        // Default to middle-right position (between upper and middle)
        var x: CGFloat = windowWidth - 100 // More centered from right edge
        var y: CGFloat = windowHeight * 0.35 // 35% from top (between upper and middle)
        
        // When expanded, adjust position to ensure full visibility
        if isExpanded {
            // Ensure the expanded panel fits within the window
            let rightEdgeSpace = windowWidth - x - expandedWidth/2
            
            if rightEdgeSpace < 20 {
                // Too close to right edge, move left
                x = windowWidth - expandedWidth/2 - 30
            }
            
            // Ensure vertical position keeps panel visible
            let expandedHeight: CGFloat = 300 // Approximate height
            if y + expandedHeight/2 > windowHeight - 20 {
                // Too low, move up
                y = windowHeight - expandedHeight/2 - 30
            } else if y - expandedHeight/2 < 20 {
                // Too high, move down
                y = expandedHeight/2 + 30
            }
        }
        
        // Apply drag offset
        return CGPoint(
            x: max(bubbleSize.width/2, min(geometry.size.width - bubbleSize.width/2, x)),
            y: max(bubbleSize.height/2, min(geometry.size.height - bubbleSize.height/2, y))
        )
    }
    
    
    private func updatePosition() {
        // Keep the bubble in a fixed, pleasant position
        // No need to follow cursor for better UX
    }
    
    private func animateIn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                bubbleOpacity = 1
                scale = 1
            }
        }
    }
    
    // MARK: - AI Actions
    
    private func generateContinuation() async {
        isThinking = true
        suggestions = []
        
        do {
            let context = extractContext()
            let continuations = try await writingService.generateSuggestions(
                for: context.current,
                previousContext: context.previous,
                context: .continuation
            )
            
            await MainActor.run {
                suggestions = continuations.prefix(3).map { text in
                    Suggestion(
                        text: text,
                        type: .continuation,
                        icon: "arrow.right.circle",
                        color: .blue
                    )
                }
                isThinking = false
            }
        } catch {
            await MainActor.run {
                isThinking = false
                // Show error state
            }
        }
    }
    
    private func generateIdeas() async {
        isThinking = true
        suggestions = []
        
        do {
            let context = extractContext()
            let ideas = try await writingService.generateSuggestions(
                for: context.current,
                previousContext: context.previous,
                context: .ideation
            )
            
            await MainActor.run {
                suggestions = ideas.prefix(4).map { text in
                    Suggestion(
                        text: text,
                        type: .idea,
                        icon: "lightbulb",
                        color: .orange
                    )
                }
                isThinking = false
            }
        } catch {
            await MainActor.run {
                isThinking = false
            }
        }
    }
    
    private func improveStyle() async {
        isThinking = true
        suggestions = []
        
        do {
            let context = extractContext()
            let improvements = try await writingService.generateSuggestions(
                for: context.current,
                previousContext: context.previous,
                context: .styleImprovement
            )
            
            await MainActor.run {
                suggestions = improvements.map { text in
                    Suggestion(
                        text: text,
                        type: .style,
                        icon: "text.quote",
                        color: .purple
                    )
                }
                isThinking = false
            }
        } catch {
            await MainActor.run {
                isThinking = false
            }
        }
    }
    
    private func breakWritersBlock() async {
        isThinking = true
        suggestions = []
        
        do {
            let prompts = try await writingService.getWritersBlockPrompts()
            
            await MainActor.run {
                suggestions = prompts.prefix(4).map { prompt in
                    Suggestion(
                        text: prompt.prompt,
                        type: .question,
                        icon: "sparkles",
                        color: .green
                    )
                }
                isThinking = false
            }
        } catch {
            await MainActor.run {
                isThinking = false
            }
        }
    }
    
    private func extractContext() -> (current: String, previous: String?) {
        // Extract current paragraph
        let paragraphRange = findParagraphRange(in: currentText, at: selectedRange.location)
        let currentParagraph = String(currentText[paragraphRange])
        
        // Extract previous paragraph if available
        var previousParagraph: String? = nil
        if paragraphRange.lowerBound > currentText.startIndex {
            let beforeIndex = currentText.index(before: paragraphRange.lowerBound)
            let prevRange = findParagraphRange(in: currentText, at: beforeIndex.utf16Offset(in: currentText))
            previousParagraph = String(currentText[prevRange])
        }
        
        return (currentParagraph, previousParagraph)
    }
    
    private func findParagraphRange(in text: String, at location: Int) -> Range<String.Index> {
        let nsString = text as NSString
        var paragraphStart = location
        var paragraphEnd = location
        
        nsString.getParagraphStart(&paragraphStart, end: &paragraphEnd, contentsEnd: nil, for: NSRange(location: location, length: 0))
        
        let startIndex = text.index(text.startIndex, offsetBy: min(paragraphStart, text.count))
        let endIndex = text.index(text.startIndex, offsetBy: min(paragraphEnd, text.count))
        
        return startIndex..<endIndex
    }
    
    // MARK: - Helper Methods
    
    private func calculatePanelHeight() -> CGFloat {
        if currentTab == .tools {
            // Fixed height for tools to show all 4 options comfortably
            return suggestions.isEmpty ? 220 : min(CGFloat(suggestions.count) * 55 + 40, 300)
        } else {
            // Dynamic height for ideas with category selector
            return 280
        }
    }
    
    private func loadWritingPrompts() {
        isThinking = true
        writingPrompts = []
        
        // Simulate AI-powered prompt generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            writingPrompts = generatePromptsForCategory(selectedPromptCategory)
            isThinking = false
        }
    }
    
    private func generatePromptsForCategory(_ category: PromptCategory) -> [WritingPrompt] {
        switch category {
        case .inspiration:
            return [
                WritingPrompt(text: "Write about a moment when you felt completely at peace. What made it special?", category: category),
                WritingPrompt(text: "Describe a person who changed your perspective on life.", category: category),
                WritingPrompt(text: "What would you tell your younger self if you could?", category: category)
            ]
        case .memory:
            return [
                WritingPrompt(text: "Recall your earliest memory. What details can you remember?", category: category),
                WritingPrompt(text: "Describe a place from your childhood that no longer exists.", category: category),
                WritingPrompt(text: "Write about a tradition that shaped who you are.", category: category)
            ]
        case .sensory:
            return [
                WritingPrompt(text: "Close your eyes. What do you hear right now? Describe each sound.", category: category),
                WritingPrompt(text: "Describe the last meal you truly savored.", category: category),
                WritingPrompt(text: "Write about a texture that brings back memories.", category: category)
            ]
        case .whatIf:
            return [
                WritingPrompt(text: "What if you woke up with a completely different skill?", category: category),
                WritingPrompt(text: "Imagine your life if you'd made that other choice.", category: category),
                WritingPrompt(text: "What if you could relive one day? Which would it be?", category: category)
            ]
        }
    }
}

// MARK: - Supporting Views

struct AssistantTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? Theme.Colors.primaryAccent : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.Colors.primaryAccent.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Theme.Colors.primaryAccent.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ActionItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon with subtle background
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(isHovered ? 0.15 : 0.08))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1 : 0.3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct CategoryPill: View {
    let category: AIAssistantBubble.PromptCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 13))
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : category.color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? category.color : category.color.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(category.color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct WritingPromptCard: View {
    let prompt: AIAssistantBubble.WritingPrompt
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: prompt.category.icon)
                        .font(.system(size: 12))
                        .foregroundColor(prompt.category.color)
                    
                    Text(prompt.category.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(prompt.category.color)
                    
                    Spacer()
                }
                
                Text(prompt.text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.8 : 0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(prompt.category.color.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct RefinedSuggestionRow: View {
    let suggestion: AIAssistantBubble.Suggestion
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon with subtle background
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(suggestion.color.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 14))
                        .foregroundColor(suggestion.color)
                }
                
                Text(suggestion.text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.6 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(suggestion.color.opacity(isHovered ? 0.2 : 0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Supporting Views

struct SuggestionRow: View {
    let suggestion: AIAssistantBubble.Suggestion
    let onTap: () -> Void
    
    @State private var isHovered = false
    
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
                    .lineLimit(3)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? suggestion.color.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(suggestion.color.opacity(isHovered ? 0.2 : 0), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
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
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.08))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.15), lineWidth: 1)
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
                    .fill(Theme.Colors.primaryAccent)
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

// MARK: - Extensions

extension CGFloat {
    func cgPoint(x: CGFloat) -> CGPoint {
        CGPoint(x: x, y: self)
    }
}

extension CGSize {
    var isZero: Bool {
        width == 0 && height == 0
    }
}