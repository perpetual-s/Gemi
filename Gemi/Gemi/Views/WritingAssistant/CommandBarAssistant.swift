import SwiftUI
import Combine

/// Modern command bar style writing assistant that appears inline at cursor
struct CommandBarAssistant: View {
    @Binding var isVisible: Bool
    @Binding var currentText: String
    @Binding var selectedRange: NSRange
    @Binding var cursorRect: CGRect
    
    @StateObject private var writingService = WritingAssistanceService()
    @State private var navigationStack: [NavigationLevel] = [.main]
    @State private var suggestions: [Suggestion] = []
    @State private var isLoading = false
    @State private var selectedIndex = 0
    @State private var searchText = ""
    @State private var responseLength: ResponseLength = .medium
    @State private var expandedSuggestions: Set<UUID> = []
    
    let onSuggestionAccepted: (String) -> Void
    
    enum NavigationLevel: Equatable {
        case main
        case tool(ToolType)
        case suggestions
        
        var title: String {
            switch self {
            case .main: return "Writing Tools"
            case .tool(let type): return type.title
            case .suggestions: return "Suggestions"
            }
        }
        
        var icon: String {
            switch self {
            case .main: return "wand.and.stars"
            case .tool(let type): return type.icon
            case .suggestions: return "text.quote"
            }
        }
    }
    
    enum ToolType: String, CaseIterable {
        case continueWriting = "Continue"
        case ideas = "Ideas"
        case improve = "Improve"
        case breakBlock = "Break Block"
        
        var title: String { rawValue }
        
        var icon: String {
            switch self {
            case .continueWriting: return "arrow.right.circle"
            case .ideas: return "lightbulb"
            case .improve: return "text.quote"
            case .breakBlock: return "sparkles"
            }
        }
        
        var color: Color {
            switch self {
            case .continueWriting: return .blue
            case .ideas: return .orange
            case .improve: return .purple
            case .breakBlock: return .green
            }
        }
        
        var description: String {
            switch self {
            case .continueWriting: return "Continue your thought naturally"
            case .ideas: return "Explore new directions"
            case .improve: return "Enhance style and clarity"
            case .breakBlock: return "Get unstuck with prompts"
            }
        }
    }
    
    enum ResponseLength: String, CaseIterable {
        case short = "Short"
        case medium = "Medium"
        case detailed = "Detailed"
        
        var maxTokens: Int {
            switch self {
            case .short: return 50
            case .medium: return 150
            case .detailed: return 300
            }
        }
    }
    
    struct Suggestion: Identifiable {
        let id = UUID()
        let text: String
        let type: SuggestionType
        let icon: String
        let color: Color
        var isExpanded: Bool = false
        
        enum SuggestionType {
            case continuation
            case idea
            case improvement
            case prompt
        }
        
        var preview: String {
            String(text.prefix(100)) + (text.count > 100 ? "..." : "")
        }
        
        var needsExpansion: Bool {
            text.count > 100
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation breadcrumb
            navigationHeader
            
            Divider()
            
            // Main content area
            contentView
                .frame(minHeight: 200, maxHeight: 600)
            
            // Footer with controls
            if navigationStack.last != .main {
                Divider()
                footerControls
            }
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            ZStack {
                // Base blur material
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                
                // Gradient overlay with blue tint
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.08),
                                Color.blue.opacity(0.04),
                                Color.purple.opacity(0.03),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Radial gradient for depth
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.blue.opacity(0.05),
                                Color.clear
                            ],
                            center: .top,
                            startRadius: 20,
                            endRadius: 200
                        )
                    )
            }
            .shadow(color: Color.blue.opacity(0.08), radius: 20, x: 0, y: 10)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.blue.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            // Focus management would go here
        }
        .onKeyPress(.escape) {
            navigateBack()
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            let maxIndex = currentLevel == .main ? ToolType.allCases.count - 1 : suggestions.count - 1
            if selectedIndex < maxIndex {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            handleSelection()
            return .handled
        }
    }
    
    // MARK: - Navigation
    
    private var navigationHeader: some View {
        HStack(spacing: 12) {
            // Back button
            if navigationStack.count > 1 {
                Button {
                    navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Go back (Esc)")
            }
            
            // Breadcrumb
            HStack(spacing: 6) {
                ForEach(Array(navigationStack.enumerated()), id: \.offset) { index, level in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: level.icon)
                            .font(.system(size: 12))
                        Text(level.title)
                            .font(.system(size: 13, weight: index == navigationStack.count - 1 ? .medium : .regular))
                    }
                    .foregroundColor(index == navigationStack.count - 1 ? .primary : .secondary)
                }
            }
            
            Spacer()
            
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        switch currentLevel {
        case .main:
            mainMenuView
        case .tool(let toolType):
            toolView(for: toolType)
        case .suggestions:
            suggestionsListView
        }
    }
    
    private var mainMenuView: some View {
        VStack(spacing: 2) {
            ForEach(Array(ToolType.allCases.enumerated()), id: \.element) { index, tool in
                ToolMenuItem(
                    tool: tool,
                    isSelected: index == selectedIndex,
                    action: {
                        selectTool(tool)
                    }
                )
            }
        }
        .padding(8)
    }
    
    private func toolView(for tool: ToolType) -> some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if !suggestions.isEmpty {
                suggestionsListView
            } else {
                // Tool-specific options
                toolOptionsView(for: tool)
            }
        }
    }
    
    private var suggestionsListView: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    CommandBarSuggestionRow(
                        suggestion: suggestion,
                        isSelected: index == selectedIndex,
                        isExpanded: expandedSuggestions.contains(suggestion.id),
                        onAccept: {
                            acceptSuggestion(suggestion)
                        },
                        onToggleExpand: {
                            toggleExpansion(for: suggestion)
                        },
                        onCopy: {
                            copySuggestion(suggestion)
                        }
                    )
                }
            }
            .padding(8)
        }
    }
    
    private func toolOptionsView(for tool: ToolType) -> some View {
        VStack(spacing: 16) {
            // Tool description
            Text(tool.description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            
            // Response length selector for relevant tools
            if tool == .continueWriting || tool == .ideas {
                responseLengthSelector
            }
            
            // Generate button
            Button {
                Task {
                    await generateSuggestions(for: tool)
                }
            } label: {
                HStack {
                    Image(systemName: tool.icon)
                    Text("Generate \(tool.title)")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tool.color)
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Analyzing your writing...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            // Cancel button
            Button("Cancel") {
                // Cancel operation
                isLoading = false
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Footer Controls
    
    private var footerControls: some View {
        HStack(spacing: 16) {
            // Context indicator
            if !suggestions.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text("\(suggestions.count) suggestions")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Quick actions
            if !suggestions.isEmpty {
                Button {
                    regenerateSuggestions()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                        Text("Regenerate")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var responseLengthSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response Length")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(ResponseLength.allCases, id: \.self) { length in
                    ResponseLengthButton(
                        length: length,
                        isSelected: responseLength == length
                    ) {
                        responseLength = length
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Actions
    
    private var currentLevel: NavigationLevel {
        navigationStack.last ?? .main
    }
    
    private func navigateBack() {
        if navigationStack.count > 1 {
            _ = navigationStack.popLast()
            selectedIndex = 0
            suggestions = []
        } else {
            dismiss()
        }
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
    }
    
    private func selectTool(_ tool: ToolType) {
        navigationStack.append(.tool(tool))
        selectedIndex = 0
        
        // Auto-generate for some tools
        if tool == .breakBlock {
            Task {
                await generateSuggestions(for: tool)
            }
        }
    }
    
    private func handleSelection() {
        switch currentLevel {
        case .main:
            if let tool = ToolType.allCases[safe: selectedIndex] {
                selectTool(tool)
            }
        case .tool:
            // Handle tool-specific selection
            break
        case .suggestions:
            if let suggestion = suggestions[safe: selectedIndex] {
                acceptSuggestion(suggestion)
            }
        }
    }
    
    private func acceptSuggestion(_ suggestion: Suggestion) {
        onSuggestionAccepted(suggestion.text)
        dismiss()
    }
    
    private func toggleExpansion(for suggestion: Suggestion) {
        if expandedSuggestions.contains(suggestion.id) {
            expandedSuggestions.remove(suggestion.id)
        } else {
            expandedSuggestions.insert(suggestion.id)
        }
    }
    
    private func copySuggestion(_ suggestion: Suggestion) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(suggestion.text, forType: .string)
        
        // Show brief feedback
        // Could add a toast notification here
    }
    
    private func generateSuggestions(for tool: ToolType) async {
        isLoading = true
        suggestions = []
        expandedSuggestions = []
        
        do {
            let context = extractContext()
            let writingContext: WritingAssistanceService.WritingContext
            
            switch tool {
            case .continueWriting:
                writingContext = .continuation
            case .ideas:
                writingContext = .ideation
            case .improve:
                writingContext = .styleImprovement
            case .breakBlock:
                writingContext = .writersBlock
            }
            
            let results = try await writingService.generateSuggestions(
                for: context.current,
                previousContext: context.previous,
                context: writingContext
            )
            
            // Apply response length truncation
            let processedResults = results.map { text in
                limitResponseLength(text, to: responseLength)
            }
            
            await MainActor.run {
                suggestions = processedResults.enumerated().map { index, text in
                    Suggestion(
                        text: text,
                        type: suggestionType(for: tool),
                        icon: tool.icon,
                        color: tool.color
                    )
                }
                
                if !suggestions.isEmpty {
                    navigationStack.append(.suggestions)
                }
                
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                // Handle error - could show error state
            }
        }
    }
    
    private func limitResponseLength(_ text: String, to length: ResponseLength) -> String {
        let words = text.split(separator: " ")
        let maxWords = length.maxTokens / 2 // Rough approximation
        
        if words.count <= maxWords {
            return text
        }
        
        let truncated = words.prefix(maxWords).joined(separator: " ")
        return truncated + "..."
    }
    
    private func regenerateSuggestions() {
        if case .tool(let toolType) = navigationStack[navigationStack.count - 2] {
            Task {
                await generateSuggestions(for: toolType)
            }
        }
    }
    
    private func suggestionType(for tool: ToolType) -> Suggestion.SuggestionType {
        switch tool {
        case .continueWriting: return .continuation
        case .ideas: return .idea
        case .improve: return .improvement
        case .breakBlock: return .prompt
        }
    }
    
    private func extractContext() -> (current: String, previous: String?) {
        // Similar to bubble implementation
        let paragraphRange = findParagraphRange(in: currentText, at: selectedRange.location)
        let currentParagraph = String(currentText[paragraphRange])
        
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
}

// MARK: - Supporting Views

struct ToolMenuItem: View {
    let tool: CommandBarAssistant.ToolType
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon with colored background
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tool.color.opacity(isSelected ? 0.18 : 0.1),
                                    tool.color.opacity(isSelected ? 0.12 : 0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: tool.icon)
                        .font(.system(size: 16))
                        .foregroundColor(tool.color)
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: isSelected)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(tool.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .opacity(isSelected ? 0.8 : 0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if isSelected {
                        // Selected state with gradient
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.12),
                                        Color.blue.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Glow effect for selected
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            .blur(radius: 2)
                    } else if isHovered {
                        // Hover state with subtle gradient
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.05),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
                }
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

struct CommandBarSuggestionRow: View {
    let suggestion: CommandBarAssistant.Suggestion
    let isSelected: Bool
    let isExpanded: Bool
    let onAccept: () -> Void
    let onToggleExpand: () -> Void
    let onCopy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main content
            Button(action: onAccept) {
                HStack(alignment: .top, spacing: 12) {
                    // Icon
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 16))
                        .foregroundColor(suggestion.color)
                        .frame(width: 24, height: 24)
                        .padding(.top, 2)
                    
                    // Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isExpanded ? suggestion.text : suggestion.preview)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Expand button if needed
                        if suggestion.needsExpansion && !isExpanded {
                            Button {
                                onToggleExpand()
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Show more")
                                    Image(systemName: "chevron.down")
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer()
                    
                    // Quick actions
                    HStack(spacing: 8) {
                        Button {
                            onCopy()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")
                        .opacity(isSelected ? 1 : 0)
                        
                        Image(systemName: "return")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .opacity(isSelected ? 0.6 : 0)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            
            // Collapse button if expanded
            if isExpanded && suggestion.needsExpansion {
                Button {
                    onToggleExpand()
                } label: {
                    HStack(spacing: 4) {
                        Text("Show less")
                        Image(systemName: "chevron.up")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                    .padding(.leading, 48)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.primary.opacity(0.05) : Color.clear)
        )
    }
}

struct ResponseLengthButton: View {
    let length: CommandBarAssistant.ResponseLength
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(length.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue : Color.secondary.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extensions

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}