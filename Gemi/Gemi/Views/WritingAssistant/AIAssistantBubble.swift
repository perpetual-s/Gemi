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
    @State private var savedPosition: CGPoint = CGPoint(x: 0, y: 0)
    @State private var isDragging: Bool = false
    @GestureState private var dragLocation: CGPoint = .zero
    @State private var initialDragOffset: CGSize = .zero
    let onSuggestionAccepted: (String) -> Void
    let editorBounds: CGRect
    
    
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
            VStack(spacing: 8) {
                // Main bubble button
                bubbleButton
                
                if isExpanded {
                    expandedContent
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                        ))
                }
            }
            .position(isDragging && !isExpanded ? dragLocation : calculateOptimalPosition(in: geometry).applying(savedPosition))
            .opacity(bubbleOpacity)
            .scaleEffect(scale)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scale)
            .animation(.easeOut(duration: 0.3), value: bubbleOpacity)
            .animation(isDragging ? nil : .interactiveSpring(response: 0.3, dampingFraction: 0.85), value: savedPosition)
            .animation(isDragging ? nil : .interactiveSpring(response: 0.3, dampingFraction: 0.85), value: dragLocation)
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .local)
                    .updating($dragLocation) { value, state, _ in
                        if !isExpanded {
                            // Convert to local coordinates and apply constraints
                            let proposedLocation = value.location
                            
                            // Bubble radius for boundary calculation
                            let bubbleRadius: CGFloat = 28
                            let padding: CGFloat = 10
                            
                            // Constrain to window bounds
                            let constrainedX = max(bubbleRadius + padding, 
                                                 min(geometry.size.width - bubbleRadius - padding, proposedLocation.x))
                            let constrainedY = max(bubbleRadius + padding, 
                                                 min(geometry.size.height - bubbleRadius - padding, proposedLocation.y))
                            
                            state = CGPoint(x: constrainedX, y: constrainedY)
                        }
                    }
                    .onChanged { value in
                        if !isExpanded {
                            if !isDragging {
                                // Calculate initial offset between bubble center and cursor
                                let currentCenter = calculateOptimalPosition(in: geometry).applying(savedPosition)
                                initialDragOffset = CGSize(
                                    width: currentCenter.x - value.startLocation.x,
                                    height: currentCenter.y - value.startLocation.y
                                )
                                withAnimation(.easeOut(duration: 0.1)) {
                                    isDragging = true
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        if !isExpanded {
                            withAnimation(.easeOut(duration: 0.1)) {
                                isDragging = false
                            }
                            
                            // Calculate final position with proper constraints
                            let basePosition = calculateOptimalPosition(in: geometry)
                            let finalWithOffset = value.location.applying(initialDragOffset)
                            
                            // Calculate offset from base position
                            let offsetX = finalWithOffset.x - basePosition.x
                            let offsetY = finalWithOffset.y - basePosition.y
                            
                            // Ensure bubble stays fully visible
                            let bubbleRadius: CGFloat = 28
                            let maxX = geometry.size.width - basePosition.x - bubbleRadius - 10
                            let minX = -basePosition.x + bubbleRadius + 10
                            let maxY = geometry.size.height - basePosition.y - bubbleRadius - 10
                            let minY = -basePosition.y + bubbleRadius + 10
                            
                            savedPosition = CGPoint(
                                x: max(minX, min(maxX, offsetX)),
                                y: max(minY, min(maxY, offsetY))
                            )
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            updatePosition()
            animateIn()
        }
        .onChange(of: selectedRange) { oldRange, newRange in
            if savedPosition != .zero { return } // Don't update if user has dragged
            updatePosition()
        }
        .coordinateSpace(name: "bubbleSpace")
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
                // Enhanced glass morphism with beautiful blue gradient
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.Colors.primaryAccent.opacity(0.35),
                                        Theme.Colors.primaryAccent.opacity(0.25),
                                        Color.blue.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        // Inner glow effect
                        Circle()
                            .stroke(
                                RadialGradient(
                                    colors: [
                                        Theme.Colors.primaryAccent.opacity(0.4),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 28
                                ),
                                lineWidth: 2
                            )
                            .blur(radius: 2)
                    )
                
                // Beautiful border with enhanced shadow
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDragging ? 0.6 : 0.3),
                                Theme.Colors.primaryAccent.opacity(isDragging ? 0.4 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isDragging ? 2.5 : 1.5
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Theme.Colors.primaryAccent.opacity(isDragging ? 0.5 : 0.3), 
                            radius: isDragging ? 16 : 10, x: 0, y: isDragging ? 6 : 4)
                    .shadow(color: Color.blue.opacity(0.2), radius: 20, x: 0, y: 8)
                    .animation(.easeInOut(duration: 0.2), value: isDragging)
                
                // Icon with animation
                if isThinking {
                    ThinkingIndicator()
                        .frame(width: 28, height: 28)
                } else {
                    ZStack {
                        Image(systemName: isExpanded ? "xmark" : "wand.and.stars")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Theme.Colors.primaryAccent,
                                        Color.blue
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolEffect(.pulse, value: !isExpanded && suggestions.isEmpty)
                            .shadow(color: Theme.Colors.primaryAccent.opacity(0.3), radius: 4)
                        
                        // Subtle move indicator in corner when not expanded and not moved
                        if !isExpanded && savedPosition == .zero {
                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(Theme.Colors.primaryAccent.opacity(0.3))
                                .offset(x: 16, y: -16)
                                .opacity(isDragging ? 0 : 1)
                                .animation(.easeOut(duration: 0.15), value: isDragging)
                        }
                    }
                }
            }
        }
        .buttonStyle(BubbleButtonStyle())
        .help("AI Writing Assistant - Drag to move")
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7), value: isDragging)
    }
    
    private var expandedContent: some View {
        VStack(spacing: 0) {
            // Simple header for Tools
            HStack {
                Label("Writing Tools", systemImage: "wand.and.stars")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isThinking {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isExpanded = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
                .opacity(0.5)
            
            // Tools content
            toolsContent
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
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
                            subtitle: "Get writing prompts",
                            color: .green
                        ) {
                            Task { await breakWritersBlock() }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 8)
            }
        }
    }
    
    
    // MARK: - Positioning
    
    private func calculateOptimalPosition(in geometry: GeometryProxy) -> CGPoint {
        let bubbleSize = CGSize(width: 56, height: 56)
        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 220 // Fixed height for tools
        
        // Position in the middle-right area of the window
        let windowWidth = geometry.size.width
        let windowHeight = geometry.size.height
        
        // Always keep bubble on the right side
        let bubbleX: CGFloat = windowWidth - 40 // Fixed distance from right edge
        var y: CGFloat = windowHeight * 0.35
        
        // Calculate x position for the VStack center
        var x = bubbleX
        
        // When expanded, adjust x to center the VStack (bubble + panel)
        if isExpanded {
            // The VStack is centered, but we want the bubble to stay at bubbleX
            // So we need to shift the entire VStack left by half the panel width
            x = bubbleX - (panelWidth - bubbleSize.width) / 2
            
            // Ensure the panel doesn't go off screen
            let minX = panelWidth / 2 + 20
            if x < minX {
                x = minX
            }
            
            // Calculate total height needed (bubble + spacing + panel)
            let totalHeight = bubbleSize.height + 8 + panelHeight
            
            // Ensure vertical fit - panel opens below
            if y + totalHeight/2 > windowHeight - 20 {
                // Not enough space below, move up
                y = windowHeight - totalHeight/2 - 20
            }
            
            // Ensure minimum space from top
            if y - bubbleSize.height/2 < 20 {
                y = bubbleSize.height/2 + 20
            }
        }
        
        // Return the base position (drag offset handled by .offset modifier)
        return CGPoint(x: x, y: y)
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
        // If text is empty, return empty context
        guard !currentText.isEmpty else {
            return ("", nil)
        }
        
        // Extract current paragraph
        let paragraphRange = findParagraphRange(in: currentText, at: selectedRange.location)
        var currentParagraph = String(currentText[paragraphRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If current paragraph is empty, try to get surrounding text
        if currentParagraph.isEmpty {
            // Get up to 500 characters before and after cursor
            let location = min(selectedRange.location, currentText.count)
            let startIndex = max(0, location - 250)
            let endIndex = min(currentText.count, location + 250)
            
            if startIndex < endIndex {
                let start = currentText.index(currentText.startIndex, offsetBy: startIndex)
                let end = currentText.index(currentText.startIndex, offsetBy: endIndex)
                currentParagraph = String(currentText[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // If still empty, use the entire text (up to 1000 chars)
        if currentParagraph.isEmpty && !currentText.isEmpty {
            let maxLength = min(currentText.count, 1000)
            let endIndex = currentText.index(currentText.startIndex, offsetBy: maxLength)
            currentParagraph = String(currentText[currentText.startIndex..<endIndex])
        }
        
        // Extract previous paragraph if available
        var previousParagraph: String? = nil
        if paragraphRange.lowerBound > currentText.startIndex {
            let beforeIndex = currentText.index(before: paragraphRange.lowerBound)
            let prevRange = findParagraphRange(in: currentText, at: beforeIndex.utf16Offset(in: currentText))
            previousParagraph = String(currentText[prevRange]).trimmingCharacters(in: .whitespacesAndNewlines)
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
    
}

// MARK: - Supporting Views

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

extension CGPoint {
    func applying(_ offset: CGPoint) -> CGPoint {
        CGPoint(x: x + offset.x, y: y + offset.y)
    }
    
    func applying(_ size: CGSize) -> CGPoint {
        CGPoint(x: x + size.width, y: y + size.height)
    }
    
    static var zero: CGPoint {
        CGPoint(x: 0, y: 0)
    }
}