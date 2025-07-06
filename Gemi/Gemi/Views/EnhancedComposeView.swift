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
    @FocusState private var isContentFocused: Bool
    
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
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    // Title field
                    TextField("Entry Title (optional)", text: $entry.title)
                    .textFieldStyle(.plain)
                    .font(Theme.Typography.title)
                    
                    Divider()
                    
                    // Content editor
                    TextEditor(text: $entry.content)
                        .font(Theme.Typography.body)
                        .lineSpacing(8)
                        .focused($isContentFocused)
                        .frame(minHeight: 400)
                        .onChange(of: entry.content) { _, newValue in
                            wordCount = newValue.split(separator: " ").count
                            checkForWritingPatterns(newValue)
                        }
                    
                    // AI Writing suggestions
                    if let prompt = selectedPrompt {
                        WritingSuggestion(prompt: prompt) {
                            entry.content += "\n\n\(prompt)"
                            selectedPrompt = nil
                            isContentFocused = true
                        }
                    }
                    
                    Divider()
                    
                    // Metadata section
                    metadataSection
                }
                .padding()
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
    
    let moods: [Mood] = [.happy, .excited, .peaceful, .grateful, .neutral, .anxious, .sad, .frustrated, .accomplished]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: Theme.spacing) {
            ForEach(moods, id: \.self) { mood in
                EnhancedMoodButton(
                    mood: mood,
                    isSelected: selectedMood == mood,
                    action: {
                        selectedMood = selectedMood == mood ? nil : mood
                    }
                )
            }
        }
    }
}

struct EnhancedMoodButton: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(mood.emoji)
                    .font(.title)
                
                Text(mood.rawValue)
                    .font(Theme.Typography.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.spacing)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(isSelected ? Theme.Colors.primaryAccent.opacity(0.2) : Theme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .strokeBorder(
                                isSelected ? Theme.Colors.primaryAccent : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
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