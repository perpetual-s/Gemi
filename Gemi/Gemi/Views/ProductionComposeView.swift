import SwiftUI
import AppKit

/// Production-level compose view with Apple-quality design
struct ProductionComposeView: View {
    @State private var entry: JournalEntry
    let onSave: (JournalEntry) -> Void
    let onCancel: () -> Void
    let onFocusMode: ((JournalEntry) -> Void)?
    
    // Editor state
    @State private var wordCount = 0
    @State private var characterCount = 0
    @State private var isContentFocused = false
    @State private var lastSavedContent = ""
    @State private var hasUnsavedChanges = false
    
    // Separate state for mood to avoid class reference issues
    @State private var selectedMood: Mood?
    
    // Animation states
    @State private var titleOpacity = 0.0
    @State private var contentOpacity = 0.0
    @State private var metadataOpacity = 0.0
    
    // Writing assistance
    @State private var writingStreak = 0
    @State private var sessionStartTime = Date()
    @State private var writingPace = 0.0
    @State private var showingEmojiPicker = false
    @State private var selectedEmoji: String?
    @State private var textEditorCoordinator: MacTextEditor.Coordinator?
    
    // Editor tracking for AI assistant
    @State private var selectedRange = NSRange(location: 0, length: 0)
    
    // AI Assistant states
    @State private var showAIAssistant = false  // Changed to command bar style
    @State private var aiAssistantExpanded = false
    @State private var showWritersBlockBreaker = false
    @StateObject private var sentimentAnalyzer = SentimentAnalyzer()
    @StateObject private var analytics = AnalyticsService.shared
    @State private var showCommandBar = false
    @State private var commandBarPosition = CGRect.zero
    
    // New UI states
    @StateObject private var placeholderService = PlaceholderService.shared
    
    // Typing feedback states
    @StateObject private var typingMetrics = TypingMetrics()
    @State private var lastTypedPosition: CGPoint?
    
    // Computed display title that updates properly
    private var displayTitle: String {
        if !entry.title.isEmpty {
            return entry.title
        } else if !entry.content.isEmpty {
            let firstLine = entry.content.components(separatedBy: .newlines).first ?? ""
            return String(firstLine.prefix(50))
        } else {
            return "Untitled Entry"
        }
    }
    
    init(entry: JournalEntry? = nil, onSave: @escaping (JournalEntry) -> Void, onCancel: @escaping () -> Void, onFocusMode: ((JournalEntry) -> Void)? = nil) {
        let initialEntry = entry ?? JournalEntry(content: "")
        self._entry = State(initialValue: initialEntry)
        self._selectedMood = State(initialValue: initialEntry.mood)
        self.onSave = onSave
        self.onCancel = onCancel
        self.onFocusMode = onFocusMode
    }
    
    var body: some View {
        GeometryReader { rootGeometry in
            ZStack {
                VStack(spacing: 0) {
                // Professional header
                productionHeader
                
                // Main editor area
                GeometryReader { geometry in
                    ScrollViewReader { scrollProxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                // Add spacer to center content vertically when minimal
                                Spacer(minLength: 0)
                                    .frame(maxHeight: .infinity)
                                
                                // Professional content editor
                                contentEditor(in: geometry)
                                    .opacity(contentOpacity)
                                    .animation(.easeOut(duration: 0.5).delay(0.2), value: contentOpacity)
                                    .id("content")
                                
                                // Metadata section
                                metadataSection
                                    .opacity(metadataOpacity)
                                    .animation(.easeOut(duration: 0.5).delay(0.3), value: metadataOpacity)
                                    .padding(.top, 32)
                                    .padding(.horizontal, 40)
                                    .padding(.bottom, 20)
                                    .id("metadata")
                                
                                // Add spacer to center content vertically when minimal
                                Spacer(minLength: 0)
                                    .frame(maxHeight: .infinity)
                            }
                            .frame(minHeight: geometry.size.height)
                        }
                        .scrollIndicators(.never)
                        .scrollDismissesKeyboard(.interactively)
                    }
                }
            
                // Professional footer
                productionFooter
            }
            
            // Typing feedback layer (behind content)
            TypingFeedbackLayer(
                isTyping: $typingMetrics.isTyping,
                typingSpeed: $typingMetrics.currentWPM,
                lastKeyPosition: $lastTypedPosition
            )
            .zIndex(-1)
            
            // Milestone celebrations (on top)
            MilestoneCelebrationView(currentWordCount: $wordCount)
            .zIndex(100)
            
            // Command Bar Assistant overlay
            if showCommandBar {
                VStack {
                    Spacer()
                    CommandBarAssistant(
                        isVisible: $showCommandBar,
                        currentText: $entry.content,
                        selectedRange: $selectedRange,
                        cursorRect: $commandBarPosition,
                        onSuggestionAccepted: { suggestion in
                            insertTextAtCursor(suggestion)
                        }
                    )
                    .padding(.top, 100) // Ensure space from top
                    Spacer()
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.25, dampingFraction: 0.85), value: showCommandBar)
                .zIndex(1000)
            }
        }
        .frame(width: rootGeometry.size.width, height: rootGeometry.size.height)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .sheet(isPresented: $showWritersBlockBreaker) {
            WritersBlockBreaker(
                isPresented: $showWritersBlockBreaker,
                onPromptSelected: { prompt in
                    // Insert the prompt as a starting point
                    if entry.content.isEmpty {
                        entry.content = "Prompt: \(prompt.prompt)\n\n"
                    } else {
                        entry.content += "\n\nPrompt: \(prompt.prompt)\n\n"
                    }
                }
            )
        }
        .onAppear {
            titleOpacity = 1
            contentOpacity = 1
            metadataOpacity = 1
            lastSavedContent = entry.content
            updateWordCount()
            
            // Start analytics session
            analytics.startSession()
        }
        .onChange(of: entry.content) { oldValue, newValue in
            updateWordCount()
            hasUnsavedChanges = (newValue != lastSavedContent)
            
            // Analyze sentiment
            sentimentAnalyzer.analyzeText(newValue)
        }
        .onChange(of: entry.title) { oldValue, newValue in
            // Force UI update when title changes
            hasUnsavedChanges = true
        }
        .onKeyPress(.init("k"), phases: .down) { keyPress in
            if keyPress.modifiers.contains(.command) {
                toggleCommandBar()
                return .handled
            }
            return .ignored
        }
        // Focus mode shortcut handled via button
        .onDisappear {
            // Ensure session is ended if view disappears unexpectedly
            if analytics.sessionStartTime != nil {
                analytics.endSession()
            }
        }
    }
    
    // MARK: - Header
    
    private var productionHeader: some View {
        VStack(spacing: 0) {
            // Top section - Title and main actions
            VStack(spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    // Editable title in header
                    TextField("Untitled Entry", text: $entry.title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    // Right side - Main actions only
                    HStack(spacing: 12) {
                        // Cancel button - subtle
                        Button("Cancel") {
                            analytics.endSession()
                            if hasUnsavedChanges {
                                // TODO: Show confirmation dialog
                                onCancel()
                            } else {
                                onCancel()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .keyboardShortcut(.escape, modifiers: [])
                        
                        
                        // Save button - ghost style when no changes
                        Button(action: saveEntry) {
                            HStack(spacing: 6) {
                                if hasUnsavedChanges {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 6, height: 6)
                                }
                                Text("Save")
                                    .font(.system(size: 15, weight: .medium))
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(hasUnsavedChanges ? .primary : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(hasUnsavedChanges ? Color.accentColor.opacity(0.1) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            hasUnsavedChanges ? Color.accentColor : Color.secondary.opacity(0.3),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .opacity(entry.content.isEmpty ? 0.5 : 1.0)
                        .disabled(entry.content.isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                        .help("Save entry (⌘Return)")
                    }
                }
                
                // Bottom section - Greeting and Writing Tools
                HStack {
                    // Time-aware greeting
                    TimeAwareGreeting(journalStore: nil)
                    
                    Spacer()
                    
                    // Writing tools section - all grouped together
                    HStack(spacing: 16) {
                        Divider()
                            .frame(height: 20)
                            .opacity(0.3)
                        
                        // Focus Mode
                        if let onFocusMode = onFocusMode {
                            Button {
                                onFocusMode(entry)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 13))
                                    Text("Focus Mode")
                                        .font(.system(size: 13))
                                }
                                .foregroundColor(.secondary)
                                .opacity(0.9)
                            }
                            .buttonStyle(.plain)
                            .help("Enter distraction-free writing mode")
                        }
                        
                        // Writing Prompts
                        Button {
                            showWritersBlockBreaker.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 13))
                                Text("Prompts")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(showWritersBlockBreaker ? Theme.Colors.primaryAccent : .secondary)
                            .opacity(showWritersBlockBreaker ? 1 : 0.9)
                        }
                        .buttonStyle(.plain)
                        .help("Browse writing prompts and exercises")
                        
                        // Writing Tools (AI)
                        Button(action: toggleCommandBar) {
                            HStack(spacing: 6) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 13))
                                Text("Writing Tools")
                                    .font(.system(size: 13))
                                Text("⌘K")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                            }
                            .foregroundColor(showCommandBar ? Theme.Colors.primaryAccent : .secondary)
                            .opacity(showCommandBar ? 1 : 0.9)
                        }
                        .buttonStyle(.plain)
                        .help("Open Writing Tools (⌘K)")
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .background(
            ZStack {
                // Subtle gradient background
                LinearGradient(
                    colors: [
                        Color(NSColor.windowBackgroundColor),
                        Color(NSColor.windowBackgroundColor).opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack {
                    Spacer()
                    Divider()
                        .opacity(0.1)
                }
            }
        )
    }
    
    
    // MARK: - Content Editor
    
    private func contentEditor(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Professional text editor
            ZStack(alignment: .topLeading) {
                // Dynamic placeholder
                if entry.content.isEmpty {
                    DynamicPlaceholder()
                        .padding(.top, 40)
                        .allowsHitTesting(false)
                        .onTapGesture {} // Ensure it doesn't interfere
                }
                
                // Custom text editor wrapper for better control
                MacTextEditor(
                    text: $entry.content,
                    isFirstResponder: isContentFocused,
                    font: .systemFont(ofSize: 17, weight: .regular),
                    textColor: .labelColor,
                    backgroundColor: .clear,
                    lineSpacing: 1.6,
                    onTextChange: { newText in
                        updateWordCount()
                        // Track typing for feedback
                        if let lastChar = newText.last {
                            typingMetrics.recordKeystroke(character: lastChar)
                        }
                    },
                    onCoordinatorReady: { coordinator in
                        textEditorCoordinator = coordinator
                    },
                    onSelectionChange: { range in
                        selectedRange = range
                    }
                )
                .frame(minHeight: 400)
                .padding(.top, 40)
            }
            .padding(.horizontal, 40)
            
            // Writing progress indicator
            if isContentFocused && wordCount > 0 {
                writingProgressView
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Sentiment indicator
            if wordCount > 10 && sentimentAnalyzer.currentAnalysis.confidence > 0.3 {
                SentimentIndicator(sentiment: sentimentAnalyzer.currentAnalysis)
                    .frame(maxWidth: 400)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                    ))
            }
        }
    }
    
    // MARK: - Writing Progress
    
    private var writingProgressView: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 3)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: progressColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressPercentage, height: 3)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: wordCount)
                }
            }
            .frame(height: 3)
            
            // Stats
            HStack(spacing: 20) {
                // Word count
                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 11))
                    Text("\(wordCount) words")
                        .font(.system(size: 12))
                }
                
                // Writing time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(formatWritingTime())
                        .font(.system(size: 12))
                }
                
                // Writing pace
                if writingPace > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 11))
                        Text("\(Int(writingPace)) wpm")
                            .font(.system(size: 12))
                    }
                }
                
                Spacer()
                
                // Achievement indicator
                if wordCount >= 750 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                        Text("Daily goal achieved!")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundColor(.secondary)
        }
    }
    
    private var progressColors: [Color] {
        if wordCount < 100 {
            return [Color.blue.opacity(0.6), Color.blue]
        } else if wordCount < 300 {
            return [Color.green.opacity(0.6), Color.green]
        } else if wordCount < 500 {
            return [Color.orange.opacity(0.6), Color.orange]
        } else {
            return [Color.purple.opacity(0.6), Color.purple]
        }
    }
    
    private var progressPercentage: Double {
        min(Double(wordCount) / 750.0, 1.0)
    }
    
    // MARK: - Metadata Section
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Mood selector
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("How are you feeling?")
                        .font(.system(size: 15, weight: .medium))
                    
                    Spacer()
                    
                    // Show selected mood prominently
                    if let mood = selectedMood {
                        HStack(spacing: 6) {
                            Text(mood.emoji)
                                .font(.system(size: 20))
                            Text(mood.rawValue.capitalized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(Color.blue, lineWidth: 1.5)
                                )
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                
                ProductionMoodPicker(selectedMood: Binding(
                    get: { selectedMood },
                    set: { newMood in
                        selectedMood = newMood
                        entry.mood = newMood
                    }
                ))
            }
            
            // Additional options
            HStack(spacing: 20) {
                // Favorite toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        entry.isFavorite.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        ZStack {
                            // Glow effect
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                                .blur(radius: 8)
                                .opacity(entry.isFavorite ? 0.6 : 0)
                                .scaleEffect(entry.isFavorite ? 1.5 : 0.8)
                                .animation(.easeOut(duration: 0.25), value: entry.isFavorite)
                            
                            // Main star
                            Image(systemName: entry.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundColor(entry.isFavorite ? .yellow : .secondary)
                                .scaleEffect(entry.isFavorite ? 1.1 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: entry.isFavorite)
                        }
                        Text(entry.isFavorite ? "Favorited" : "Add to favorites")
                            .font(.system(size: 13))
                            .foregroundColor(entry.isFavorite ? .primary : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(entry.isFavorite ? Color.yellow.opacity(0.1) : Color.clear)
                            .animation(.easeInOut(duration: 0.2), value: entry.isFavorite)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
    }
    
    // MARK: - Footer
    
    private var productionFooter: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 20) {
                // Writing stats
                HStack(spacing: 16) {
                    StatLabel(
                        icon: "character",
                        value: "\(characterCount)",
                        label: "characters"
                    )
                    
                    Divider()
                        .frame(height: 16)
                    
                    StatLabel(
                        icon: "text.alignleft",
                        value: "\(wordCount)",
                        label: "words"
                    )
                    
                    Divider()
                        .frame(height: 16)
                    
                    StatLabel(
                        icon: "book",
                        value: "\(entry.readingTime)",
                        label: "min read"
                    )
                }
                
                Spacer()
                
                // Auto-save indicator
                if hasUnsavedChanges {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                        Text("Unsaved changes")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("All changes saved")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(VisualEffectView.headerView)
        }
    }
    
    // MARK: - Helper Functions
    
    private func updateWordCount() {
        let words = entry.content.split { $0.isWhitespace || $0.isNewline }
        wordCount = words.filter { !$0.isEmpty }.count
        characterCount = entry.content.count
        
        // Calculate writing pace
        let timeElapsed = Date().timeIntervalSince(sessionStartTime) / 60.0 // minutes
        if timeElapsed > 0 {
            writingPace = Double(wordCount) / timeElapsed
        }
    }
    
    private func formatWritingTime() -> String {
        let elapsed = Date().timeIntervalSince(sessionStartTime)
        let minutes = Int(elapsed / 60)
        let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func saveEntry() {
        lastSavedContent = entry.content
        hasUnsavedChanges = false
        
        // Track session analytics
        analytics.updateSessionWithWords(entry.wordCount)
        analytics.endSession()
        
        // Record entry for placeholder service
        placeholderService.recordEntry()
        
        onSave(entry)
    }
    
    private func insertTextAtCursor(_ text: String) {
        if let coordinator = textEditorCoordinator {
            coordinator.insertTextAtCursor(text)
        } else {
            // Fallback: append to content
            entry.content += text
        }
    }
    
    
    private func toggleCommandBar() {
        if showCommandBar {
            withAnimation(.easeOut(duration: 0.2)) {
                showCommandBar = false
            }
        } else {
            // Update cursor position before showing
            updateCommandBarPosition()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                showCommandBar = true
            }
        }
    }
    
    private func updateCommandBarPosition() {
        // Get current cursor rect from text editor
        if let coordinator = textEditorCoordinator,
           let textView = coordinator.textView {
            let selectedRange = textView.selectedRange()
            let rect = textView.firstRect(forCharacterRange: selectedRange, actualRange: nil)
            commandBarPosition = rect
        }
    }
    
}

// MARK: - Supporting Views

struct StatLabel: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Production Mood Picker

struct ProductionMoodPicker: View {
    @Binding var selectedMood: Mood?
    
    let moods: [Mood] = Mood.allCases
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(moods, id: \.self) { mood in
                ProductionMoodButton(
                    mood: mood,
                    isSelected: selectedMood == mood
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedMood = selectedMood == mood ? nil : mood
                    }
                }
            }
        }
    }
}

struct ProductionMoodButton: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(mood.emoji)
                    .font(.system(size: 24))
                
                Text(mood.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? Color.blue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Color.blue : Color.secondary.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(color: isSelected ? Color.blue.opacity(0.4) : Color.clear, radius: 4)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Production Tag Editor



// MARK: - Custom Text Editor

struct MacTextEditor: NSViewRepresentable {
    @Binding var text: String
    let isFirstResponder: Bool
    let font: NSFont
    let textColor: NSColor
    let backgroundColor: NSColor
    let lineSpacing: CGFloat
    let onTextChange: (String) -> Void
    var onCoordinatorReady: ((Coordinator) -> Void)?
    var onSelectionChange: ((NSRange) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        
        // Set line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing * font.pointSize - font.pointSize
        textView.defaultParagraphStyle = paragraphStyle
        
        // Store reference to textView for cursor operations
        context.coordinator.textView = textView
        
        // Notify that coordinator is ready
        onCoordinatorReady?(context.coordinator)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Update text only if changed to prevent unnecessary updates
        if textView.string != text && !context.coordinator.isUpdating {
            context.coordinator.isUpdating = true
            textView.string = text
            context.coordinator.isUpdating = false
        }
        
        // Handle first responder status on main thread
        if isFirstResponder {
            let needsFocus = textView.window?.firstResponder !== textView
            if needsFocus {
                DispatchQueue.main.async { [weak textView] in
                    textView?.window?.makeFirstResponder(textView)
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacTextEditor
        var isUpdating = false
        weak var textView: NSTextView?
        
        init(_ parent: MacTextEditor) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }
            
            parent.text = textView.string
            parent.onTextChange(textView.string)
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.onSelectionChange?(textView.selectedRange())
        }
        
        @MainActor
        func insertTextAtCursor(_ text: String) {
            guard let textView = textView else { return }
            
            // Get current selection range
            let selectedRange = textView.selectedRange()
            
            // Insert text at cursor position
            if textView.shouldChangeText(in: selectedRange, replacementString: text) {
                textView.replaceCharacters(in: selectedRange, with: text)
                textView.didChangeText()
                
                // Move cursor after inserted text
                let newCursorPosition = selectedRange.location + text.count
                textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))
            }
        }
    }
}


