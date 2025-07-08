import SwiftUI
import AppKit

/// Production-level compose view with Apple-quality design
struct ProductionComposeView: View {
    @State private var entry: JournalEntry
    let onSave: (JournalEntry) -> Void
    let onCancel: () -> Void
    
    // Editor state
    @State private var wordCount = 0
    @State private var characterCount = 0
    @State private var isContentFocused = false
    @State private var lastSavedContent = ""
    @State private var hasUnsavedChanges = false
    
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
    
    init(entry: JournalEntry? = nil, onSave: @escaping (JournalEntry) -> Void, onCancel: @escaping () -> Void) {
        self._entry = State(initialValue: entry ?? JournalEntry(content: ""))
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Professional header
            productionHeader
            
            // Main editor area
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Title section with subtle animations
                        titleSection
                            .opacity(titleOpacity)
                            .animation(.easeOut(duration: 0.5).delay(0.1), value: titleOpacity)
                        
                        // Professional content editor
                        contentEditor(in: geometry)
                            .opacity(contentOpacity)
                            .animation(.easeOut(duration: 0.5).delay(0.2), value: contentOpacity)
                        
                        // Metadata section
                        metadataSection
                            .opacity(metadataOpacity)
                            .animation(.easeOut(duration: 0.5).delay(0.3), value: metadataOpacity)
                            .padding(.top, 32)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 20)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            
            // Professional footer
            productionFooter
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            titleOpacity = 1
            contentOpacity = 1
            metadataOpacity = 1
            lastSavedContent = entry.content
            updateWordCount()
        }
        .onChange(of: entry.content) { oldValue, newValue in
            updateWordCount()
            hasUnsavedChanges = (newValue != lastSavedContent)
        }
    }
    
    // MARK: - Header
    
    private var productionHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Document icon with unsaved indicator
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    
                    if hasUnsavedChanges {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -2)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Emoji picker
                Button {
                    showingEmojiPicker.toggle()
                } label: {
                    Text("😊")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .help("Insert emoji")
                .popover(isPresented: $showingEmojiPicker) {
                    QuickEmojiPicker(
                        onEmojiSelected: { emoji in
                            // Insert emoji at cursor position
                            if let coordinator = textEditorCoordinator {
                                coordinator.insertTextAtCursor(emoji)
                            } else {
                                // Fallback: append to content
                                entry.content += emoji
                            }
                        },
                        isPresented: $showingEmojiPicker
                    )
                }
                
                
                Divider()
                    .frame(height: 20)
                
                // Action buttons
                Button("Cancel") {
                    if hasUnsavedChanges {
                        // Show confirmation dialog
                        onCancel()
                    } else {
                        onCancel()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button("Save") {
                    saveEntry()
                }
                .buttonStyle(.borderedProminent)
                .disabled(entry.content.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
        }
        .background(ProductionVisualEffectView())
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title with professional styling
            TextField("Untitled", text: $entry.title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .lineLimit(1...3)
                .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 40)
            .padding(.top, 32)
            
            // Subtle divider
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 40)
                .padding(.top, 20)
        }
    }
    
    // MARK: - Content Editor
    
    private func contentEditor(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Professional text editor
            ZStack(alignment: .topLeading) {
                // Placeholder
                if entry.content.isEmpty {
                    Text("Start writing...")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.top, 24)
                        .allowsHitTesting(false)
                }
                
                // Custom text editor wrapper for better control
                MacTextEditor(
                    text: $entry.content,
                    isFirstResponder: isContentFocused,
                    font: .systemFont(ofSize: 17, weight: .regular),
                    textColor: .labelColor,
                    backgroundColor: .clear,
                    lineSpacing: 1.6,
                    onTextChange: { _ in
                        updateWordCount()
                    },
                    onCoordinatorReady: { coordinator in
                        textEditorCoordinator = coordinator
                    }
                )
                .frame(minHeight: 400)
                .padding(.top, 20)
            }
            .padding(.horizontal, 40)
            
            // Writing progress indicator
            if isContentFocused && wordCount > 0 {
                writingProgressView
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    
                }
                
                ProductionMoodPicker(selectedMood: $entry.mood)
            }
            
            // Tags
            VStack(alignment: .leading, spacing: 12) {
                Text("Tags")
                    .font(.system(size: 15, weight: .medium))
                
                ProductionTagEditor(tags: $entry.tags)
            }
            
            // Additional options
            HStack(spacing: 20) {
                // Favorite toggle
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        entry.isFavorite.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: entry.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundColor(entry.isFavorite ? .yellow : .secondary)
                        Text(entry.isFavorite ? "Favorited" : "Add to favorites")
                            .font(.system(size: 13))
                    }
                }
                .buttonStyle(.plain)
                
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
            .background(ProductionVisualEffectView())
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
        onSave(entry)
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
                    withAnimation(.easeInOut(duration: 0.1)) {
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
                    .foregroundColor(isSelected ? Theme.Colors.primaryAccent : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.Colors.primaryAccent.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Theme.Colors.primaryAccent : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
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

struct ProductionTagEditor: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    @State private var isAddingTag = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Existing tags
            if !tags.isEmpty {
                ProductionFlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        ProductionTagChip(tag: tag) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                tags.removeAll { $0 == tag }
                            }
                        }
                    }
                    
                    // Add tag button
                    addTagButton
                }
            } else {
                addTagButton
            }
            
            // Tag input
            if isAddingTag {
                HStack {
                    Image(systemName: "number")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    TextField("Add tag", text: $newTag)
                        .textFieldStyle(.plain)
                        .focused($isInputFocused)
                        .onSubmit {
                            addTag()
                        }
                    
                    Button("Add") {
                        addTag()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(newTag.isEmpty)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.05))
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .onAppear {
                    isInputFocused = true
                }
            }
        }
    }
    
    private var addTagButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isAddingTag.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                Text("Add tag")
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                tags.append(trimmedTag)
                newTag = ""
                isAddingTag = false
            }
        }
    }
}

struct ProductionTagChip: View {
    let tag: String
    let onRemove: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 6) {
            Text("#\(tag)")
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.primaryAccent)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Colors.primaryAccent.opacity(0.1))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Flow Layout

struct ProductionFlowLayout: Layout {
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

// MARK: - Visual Effect View

struct ProductionVisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .headerView
        view.blendingMode = .withinWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

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


