import SwiftUI

/// Enhanced compose view with AI writing assistance
struct EnhancedComposeView: View {
    @State private var entry: JournalEntry
    let onSave: (JournalEntry) -> Void
    let onCancel: () -> Void
    
    @State private var showingAIAssistant = false
    @State private var showingPrompts = false
    @State private var isGeneratingPrompt = false
    @State private var selectedPrompt: String?
    @State private var wordCount = 0
    @State private var isAnalyzingMood = false
    @State private var suggestedMood: Mood?
    @State private var isBoldActive = false
    @State private var isItalicActive = false
    @State private var isListActive = false
    @State private var focusMode = false
    @FocusState private var isContentFocused: Bool
    @State private var selectedRange: NSRange?
    @State private var showFormattingBar = false
    @State private var scrollOffset: CGFloat = 0
    
    init(entry: JournalEntry? = nil, onSave: @escaping (JournalEntry) -> Void, onCancel: @escaping () -> Void) {
        self._entry = State(initialValue: entry ?? JournalEntry(content: ""))
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // AI Assistant Bar
            if showingAIAssistant {
                AIAssistantBar(
                    onPrompt: { showingPrompts = true },
                    onContinue: continueWriting,
                    onAnalyzeMood: analyzeMood,
                    onExtractKeyPoints: extractKeyPoints
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Enhanced title field with character count
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .leading) {
                            if entry.title.isEmpty {
                                Text("Give your entry a title...")
                                    .font(Theme.Typography.title)
                                    .foregroundColor(Theme.Colors.tertiaryText.opacity(0.5))
                                    .allowsHitTesting(false)
                            }
                            
                            TextField("", text: $entry.title)
                                .textFieldStyle(.plain)
                                .font(Theme.Typography.title)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Title character count
                        if !entry.title.isEmpty {
                            Text("\(entry.title.count) characters")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.tertiaryText)
                                .padding(.horizontal)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    // Removed non-functional formatting toolbar
                    Divider()
                        .padding(.horizontal)
                        .opacity(0.5)
                    
                    // Professional content editor
                    ZStack(alignment: .topLeading) {
                        // Enhanced editor background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.Colors.windowBackground)
                            .shadow(
                                color: .black.opacity(0.04),
                                radius: 2,
                                x: 0,
                                y: 1
                            )
                        
                        VStack(spacing: 0) {
                            // Writing area with better design
                            ZStack(alignment: .topLeading) {
                                // Placeholder
                                if entry.content.isEmpty {
                                    Text("What's on your mind?")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(Theme.Colors.tertiaryText.opacity(0.5))
                                        .padding(.top, 20)
                                        .padding(.horizontal, 24)
                                        .allowsHitTesting(false)
                                }
                                
                                // Enhanced text editor
                                TextEditor(text: $entry.content)
                                    .font(.system(size: 17, weight: .regular))
                                    .lineSpacing(8)
                                    .focused($isContentFocused)
                                    .scrollContentBackground(.hidden)
                                    .padding(.top, 16)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 20)
                            }
                            .frame(minHeight: 450)
                            
                            // Focus mode indicator
                            if isContentFocused {
                                HStack {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.Colors.primaryAccent.opacity(0.6))
                                    
                                    Text("Writing mode")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.Colors.secondaryText)
                                    
                                    Spacer()
                                    
                                    Text("\(wordCount) words")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Theme.Colors.secondaryText)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Theme.Colors.cardBackground.opacity(0.5))
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .onChange(of: entry.content) { _, newValue in
                        wordCount = newValue.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }.count
                        checkForWritingPatterns(newValue)
                    }
                    
                    // Floating formatting toolbar
                    if showFormattingBar && isContentFocused {
                        floatingFormattingBar
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8, anchor: .top).combined(with: .opacity),
                                removal: .scale(scale: 0.8, anchor: .top).combined(with: .opacity)
                            ))
                    }
                    
                    // AI Writing suggestions
                    if let prompt = selectedPrompt {
                        WritingSuggestion(prompt: prompt) {
                            entry.content += "\n\n\(prompt)"
                            selectedPrompt = nil
                            isContentFocused = true
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                        .padding(.top, Theme.spacing)
                    
                    // Metadata section
                    metadataSection
                        .padding(.horizontal)
                        .padding(.vertical)
                }
            }
            
            Divider()
            
            // Footer
            footer
        }
        .background(Theme.Colors.windowBackground)
        .onAppear {
            isContentFocused = true
            if entry.content.isEmpty {
                generateInitialPrompt()
            }
        }
        .sheet(isPresented: $showingPrompts) {
            PromptsSheet(
                currentContent: entry.content,
                onSelectPrompt: { prompt in
                    selectedPrompt = prompt
                    showingPrompts = false
                }
            )
        }
    }
    
    private var header: some View {
        HStack {
            Text("Write")
                .font(Theme.Typography.largeTitle)
            
            Spacer()
            
            Button {
                withAnimation(Theme.smoothAnimation) {
                    showingAIAssistant.toggle()
                }
            } label: {
                Label("AI Assistant", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
            
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
            
            Button("Save") {
                if entry.mood == nil && suggestedMood != nil {
                    entry.mood = suggestedMood
                }
                onSave(entry)
            }
            .buttonStyle(.borderedProminent)
            .disabled(entry.content.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            // Mood selector with AI suggestion
            HStack {
                Text("Mood")
                    .font(Theme.Typography.headline)
                
                if isAnalyzingMood {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let suggested = suggestedMood, entry.mood == nil {
                    Button {
                        entry.mood = suggested
                    } label: {
                        Label("AI suggests: \(suggested.emoji) \(suggested.rawValue)", systemImage: "sparkles")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primaryAccent)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            
            MoodPicker(selectedMood: $entry.mood)
            
            // Tags
            Text("Tags")
                .font(Theme.Typography.headline)
            
            TagEditor(tags: $entry.tags)
            
            // Favorite toggle
            Toggle("Mark as Favorite", isOn: $entry.isFavorite)
                .toggleStyle(.switch)
        }
    }
    
    private var footer: some View {
        HStack {
            // Writing stats
            HStack(spacing: Theme.largeSpacing) {
                Label("\(wordCount) words", systemImage: "text.alignleft")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Label("\(entry.readingTime) min read", systemImage: "clock")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            Spacer()
            
            Text("Last saved: \(entry.modifiedAt.formatted(date: .omitted, time: .shortened))")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
        }
        .padding()
    }
    
    // MARK: - New Components
    
    private var formattingToolbar: some View {
        HStack(spacing: 16) {
            // Text formatting buttons
            FormatButton(
                icon: "bold",
                isActive: isBoldActive,
                action: { isBoldActive.toggle() }
            )
            
            FormatButton(
                icon: "italic",
                isActive: isItalicActive,
                action: { isItalicActive.toggle() }
            )
            
            FormatButton(
                icon: "list.bullet",
                isActive: isListActive,
                action: { isListActive.toggle() }
            )
            
            Divider()
                .frame(height: 20)
            
            // Additional tools
            Button {
                // Insert current date/time
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
                entry.content += "\n\n---\n\(formatter.string(from: Date()))\n"
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .buttonStyle(.plain)
            .help("Insert date & time")
            
            Spacer()
            
            // Focus mode toggle
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    focusMode.toggle()
                }
            } label: {
                Label(
                    focusMode ? "Exit Focus Mode" : "Focus Mode",
                    systemImage: focusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                )
                .font(.system(size: 13))
                .foregroundColor(focusMode ? Theme.Colors.primaryAccent : Theme.Colors.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.Colors.cardBackground.opacity(0.5))
        )
    }
    
    private var writingProgressIndicator: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.Colors.divider.opacity(0.3))
                        .frame(height: 4)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressGradient)
                        .frame(
                            width: min(
                                geometry.size.width * progressPercentage,
                                geometry.size.width
                            ),
                            height: 4
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: wordCount)
                }
            }
            .frame(height: 4)
            
            // Stats
            HStack {
                Text(progressMessage)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Spacer()
                
                if wordCount > 100 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: progressColors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var progressColors: [Color] {
        if wordCount < 50 {
            return [Color.blue.opacity(0.6), Color.blue]
        } else if wordCount < 200 {
            return [Color.green.opacity(0.6), Color.green]
        } else if wordCount < 500 {
            return [Color.orange.opacity(0.6), Color.orange]
        } else {
            return [Color.purple.opacity(0.6), Color.purple]
        }
    }
    
    private var progressPercentage: Double {
        // Progress towards daily goal of 750 words
        return min(Double(wordCount) / 750.0, 1.0)
    }
    
    private var progressMessage: String {
        if wordCount < 50 {
            return "Getting started..."
        } else if wordCount < 200 {
            return "Nice progress!"
        } else if wordCount < 500 {
            return "You're on fire! 🔥"
        } else if wordCount < 750 {
            return "Almost at your daily goal!"
        } else {
            return "Goal achieved! Keep going? 🎉"
        }
    }
    
    // MARK: - Formatting Components
    
    private var floatingFormattingBar: some View {
        HStack(spacing: 2) {
            // Bold
            FormattingButton(
                systemImage: "bold",
                isActive: isBoldActive,
                action: { applyFormatting(.bold) }
            )
            
            // Italic
            FormattingButton(
                systemImage: "italic",
                isActive: isItalicActive,
                action: { applyFormatting(.italic) }
            )
            
            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)
            
            // Heading
            FormattingButton(
                systemImage: "textformat.size",
                isActive: false,
                action: { applyFormatting(.heading) }
            )
            
            // List
            FormattingButton(
                systemImage: "list.bullet",
                isActive: isListActive,
                action: { applyFormatting(.list) }
            )
            
            // Quote
            FormattingButton(
                systemImage: "quote.opening",
                isActive: false,
                action: { applyFormatting(.quote) }
            )
            
            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)
            
            // Link
            FormattingButton(
                systemImage: "link",
                isActive: false,
                action: { applyFormatting(.link) }
            )
            
            // Separator
            FormattingButton(
                systemImage: "minus",
                isActive: false,
                action: { insertSeparator() }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    private enum FormattingType {
        case bold, italic, heading, list, quote, link
    }
    
    private func applyFormatting(_ type: FormattingType) {
        switch type {
        case .bold:
            isBoldActive.toggle()
            if selectedRange != nil {
                // Apply bold formatting to selected text
                // This is placeholder - would need NSTextView for real implementation
            } else {
                // Formatting not implemented yet
            }
        case .italic:
            isItalicActive.toggle()
            if selectedRange != nil {
                // Apply italic formatting
            } else {
                // Formatting not implemented yet
            }
        case .heading:
            // Formatting not implemented yet
            break
        case .list:
            isListActive.toggle()
            // Formatting not implemented yet
            break
        case .quote:
            // Formatting not implemented yet
            break
        case .link:
            // Formatting not implemented yet
            break
        }
        isContentFocused = true
    }
    
    private func insertSeparator() {
        entry.content += "\n\n---\n\n"
        isContentFocused = true
    }
    
    // MARK: - AI Functions
    
    private func generateInitialPrompt() {
        Task {
            isGeneratingPrompt = true
            
            // Use the companion service to generate contextual prompts
            let prompts = await CompanionModelService.shared.generateReflectionPrompts(basedOn: [])
            
            await MainActor.run {
                if !prompts.isEmpty {
                    selectedPrompt = prompts.randomElement()
                }
                isGeneratingPrompt = false
            }
        }
    }
    
    private func continueWriting() {
        guard !entry.content.isEmpty else { return }
        
        Task {
            // This would use the AI to continue the current thought
            // For now, show a placeholder
            await MainActor.run {
                selectedPrompt = "Continue your thought about..."
            }
        }
    }
    
    private func analyzeMood() {
        guard !entry.content.isEmpty else { return }
        
        isAnalyzingMood = true
        
        Task {
            // Simulate mood analysis
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Simple mood detection based on keywords
            let content = entry.content.lowercased()
            let detectedMood: Mood = {
                if content.contains("happy") || content.contains("joy") || content.contains("excited") {
                    return .happy
                } else if content.contains("sad") || content.contains("down") {
                    return .sad
                } else if content.contains("stress") || content.contains("anxious") || content.contains("worried") {
                    return .anxious
                } else if content.contains("calm") || content.contains("peaceful") {
                    return .peaceful
                } else if content.contains("angry") || content.contains("frustrated") {
                    return .frustrated
                } else {
                    return .neutral
                }
            }()
            
            await MainActor.run {
                suggestedMood = detectedMood
                isAnalyzingMood = false
            }
        }
    }
    
    private func extractKeyPoints() {
        guard !entry.content.isEmpty else { return }
        
        // Extract potential tags from content
        let words = entry.content.components(separatedBy: .whitespacesAndNewlines)
        let commonWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for"])
        
        let potentialTags = words
            .filter { $0.count > 4 && !commonWords.contains($0.lowercased()) }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        
        let uniqueTags = Array(Set(potentialTags)).prefix(5)
        
        if !uniqueTags.isEmpty {
            entry.tags = Array(uniqueTags)
        }
    }
    
    private func checkForWritingPatterns(_ content: String) {
        // Check if user has stopped writing for a bit
        // This could trigger AI suggestions
    }
}

// MARK: - Supporting Views

struct AIAssistantBar: View {
    let onPrompt: () -> Void
    let onContinue: () -> Void
    let onAnalyzeMood: () -> Void
    let onExtractKeyPoints: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacing) {
                AssistantButton(
                    title: "Writing Prompts",
                    icon: "lightbulb",
                    action: onPrompt
                )
                
                AssistantButton(
                    title: "Continue Writing",
                    icon: "arrow.right.circle",
                    action: onContinue
                )
                
                AssistantButton(
                    title: "Analyze Mood",
                    icon: "face.smiling",
                    action: onAnalyzeMood
                )
                
                AssistantButton(
                    title: "Extract Tags",
                    icon: "tag",
                    action: onExtractKeyPoints
                )
            }
            .padding()
        }
        .background(Theme.Colors.cardBackground)
    }
}

struct AssistantButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Theme.Typography.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct WritingSuggestion: View {
    let prompt: String
    let onUse: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(Theme.Colors.primaryAccent)
            
            Text(prompt)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
            
            Spacer()
            
            Button("Use", action: onUse)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding()
        .background(Theme.Colors.primaryAccent.opacity(0.1))
        .cornerRadius(Theme.cornerRadius)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

struct PromptsSheet: View {
    let currentContent: String
    let onSelectPrompt: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var prompts: [String] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Writing Prompts")
                    .font(Theme.Typography.largeTitle)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            // Content
            if isLoading {
                ProgressView("Generating personalized prompts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: Theme.spacing) {
                        ForEach(prompts, id: \.self) { prompt in
                            PromptCard(prompt: prompt) {
                                onSelectPrompt(prompt)
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 600)
        .background(Theme.Colors.windowBackground)
        .onAppear {
            generatePrompts()
        }
    }
    
    private func generatePrompts() {
        Task {
            // Generate contextual prompts
            let contextualPrompts = await CompanionModelService.shared.generateReflectionPrompts(basedOn: [])
            
            // Add some general prompts
            let generalPrompts = [
                "What moment from today stands out the most and why?",
                "If you could tell your future self one thing, what would it be?",
                "What's something you're grateful for that you haven't written about yet?",
                "Describe a small victory you experienced recently.",
                "What's been occupying your thoughts lately?",
                "Write about a person who made a difference in your day.",
                "What would you like to let go of?",
                "Describe your ideal day from start to finish."
            ]
            
            await MainActor.run {
                prompts = contextualPrompts + generalPrompts.shuffled().prefix(5)
                isLoading = false
            }
        }
    }
}

struct PromptCard: View {
    let prompt: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.primaryAccent.opacity(0.5))
                
                Text(prompt)
                    .font(Theme.Typography.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(Theme.Colors.primaryAccent)
                    .opacity(isHovered ? 1 : 0.5)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(isHovered ? Theme.Colors.primaryAccent.opacity(0.1) : Theme.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Mood Picker

struct MoodPicker: View {
    @Binding var selectedMood: Mood?
    @State private var hoveredMood: Mood?
    
    let moods: [Mood] = [.happy, .excited, .peaceful, .grateful, .neutral, .anxious, .sad, .frustrated, .accomplished]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show selected mood with clear button
            if selectedMood != nil {
                HStack {
                    Text("Current mood:")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.tertiaryText)
                    
                    if let mood = selectedMood {
                        HStack(spacing: 4) {
                            Text(mood.emoji)
                            Text(mood.rawValue.capitalized)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.primaryAccent.opacity(0.1))
                        )
                        .foregroundColor(Theme.Colors.primaryAccent)
                    }
                    
                    Spacer()
                    
                    Button("Clear") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedMood = nil
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            
            // Enhanced mood grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(moods, id: \.self) { mood in
                    EnhancedMoodButton(
                        mood: mood,
                        isSelected: selectedMood == mood,
                        isHovered: hoveredMood == mood,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedMood = selectedMood == mood ? nil : mood
                            }
                        }
                    )
                    .onHover { isHovered in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredMood = isHovered ? mood : nil
                        }
                    }
                }
            }
        }
    }
}

struct EnhancedMoodButton: View {
    let mood: Mood
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(mood.emoji)
                    .font(.system(size: isHovered ? 26 : 22))
                    .scaleEffect(isPressed ? 0.9 : 1)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
                
                Text(mood.rawValue.capitalized)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.Colors.primaryAccent : Theme.Colors.secondaryText)
                    .opacity(isHovered ? 1 : 0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundFill)
                    .shadow(
                        color: shadowColor,
                        radius: isHovered ? 4 : 1,
                        x: 0,
                        y: isHovered ? 2 : 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                    .opacity(isSelected || isHovered ? 1 : 0)
            )
            .scaleEffect(isHovered ? 1.05 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.05, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var backgroundFill: Color {
        if isSelected {
            return Theme.Colors.primaryAccent.opacity(0.15)
        } else if isHovered {
            return Theme.Colors.cardBackground.opacity(0.8)
        } else {
            return Theme.Colors.cardBackground.opacity(0.5)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Theme.Colors.primaryAccent
        } else if isHovered {
            return Theme.Colors.primaryAccent.opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    private var shadowColor: Color {
        if isSelected {
            return Theme.Colors.primaryAccent.opacity(0.2)
        } else if isHovered {
            return Color.black.opacity(0.08)
        } else {
            return Color.black.opacity(0.03)
        }
    }
}

// MARK: - Tag Editor

struct TagEditor: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    @State private var suggestedTags: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            // Existing tags
            if !tags.isEmpty {
                EnhancedFlowLayout(spacing: Theme.smallSpacing) {
                    ForEach(tags, id: \.self) { tag in
                        EnhancedTagChip(tag: tag) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }
            
            // Add new tag
            HStack {
                TextField("Add tag...", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addTag()
                    }
                
                Button("Add", action: addTag)
                    .disabled(newTag.isEmpty)
            }
            
            // Suggested tags
            if !suggestedTags.isEmpty {
                Text("Suggestions:")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                HStack {
                    ForEach(suggestedTags, id: \.self) { tag in
                        Button(tag) {
                            if !tags.contains(tag) {
                                tags.append(tag)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
    
    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
            newTag = ""
        }
    }
}

struct EnhancedTagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(Theme.Typography.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.smallSpacing)
        .padding(.vertical, 4)
        .background(Theme.Colors.primaryAccent.opacity(0.2))
        .cornerRadius(Theme.smallCornerRadius)
    }
}

// MARK: - Flow Layout

struct EnhancedFlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangement(proposal: proposal, subviews: subviews)
        return CGSize(width: result.width, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangement(proposal: proposal, subviews: subviews)
        
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
    
    private func arrangement(proposal: ProposedViewSize, subviews: Subviews) -> (frames: [CGRect], width: CGFloat, height: CGFloat) {
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > (proposal.width ?? .infinity) && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxWidth = max(maxWidth, currentX - spacing)
        }
        
        return (frames, maxWidth, currentY + lineHeight)
    }
}

// MARK: - Format Button

struct FormatButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? Theme.Colors.primaryAccent : Theme.Colors.secondaryText)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Theme.Colors.primaryAccent.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isActive ? Theme.Colors.primaryAccent.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isActive ? 1.05 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isActive)
    }
}

// MARK: - Rich Text Editor (Placeholder for future implementation)

// MARK: - Formatting Button

struct FormattingButton: View {
    let systemImage: String
    let isActive: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(
                    isActive ? .white :
                    isHovered ? Theme.Colors.primaryAccent :
                    Theme.Colors.secondaryText
                )
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            isActive ? Theme.Colors.primaryAccent :
                            isHovered ? Theme.Colors.primaryAccent.opacity(0.1) :
                            Color.clear
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(getTooltip())
    }
    
    private func getTooltip() -> String {
        switch systemImage {
        case "bold": return "Bold (⌘B)"
        case "italic": return "Italic (⌘I)"
        case "textformat.size": return "Heading"
        case "list.bullet": return "Bullet List"
        case "quote.opening": return "Quote"
        case "link": return "Insert Link (⌘K)"
        case "minus": return "Insert Separator"
        default: return ""
        }
    }
}