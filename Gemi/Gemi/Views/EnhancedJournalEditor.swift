//
//  EnhancedJournalEditor.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI
import AppKit

struct EnhancedJournalEditor: View {
    @Binding var entry: JournalEntry?
    @Binding var isPresented: Bool
    var onSave: ((JournalEntry) -> Void)?
    @Environment(NavigationModel.self) private var navigationModel
    
    @State private var title: String = ""
    @State private var content: AttributedString = AttributedString("")
    @State private var plainTextContent: String = ""
    @State private var wordCount: Int = 0
    @State private var characterCount: Int = 0
    @State private var readingTime: Int = 0
    @State private var lastSaved: Date = Date()
    @State private var autoSaveTimer: Timer?
    
    @State private var isTypewriterMode: Bool = false
    @State private var isFocusMode: Bool = false
    @State private var selectedBackground: BackgroundStyle = .paper
    @State private var isPlayingAmbientSound: Bool = false
    @State private var selectedAmbientSound: AmbientSound = .rain
    
    @State private var showingSlashCommands: Bool = false
    @State private var slashCommandQuery: String = ""
    @State private var slashCommandPosition: CGPoint = .zero
    
    @State private var showingFormattingToolbar: Bool = false
    @State private var formattingToolbarPosition: CGPoint = .zero
    @State private var selectedRange: NSRange?
    
    @State private var showingAISuggestions: Bool = false
    @State private var aiSuggestion: String = ""
    @State private var detectedMood: MoodIndicator.Mood?
    @State private var showingAIPrompts: Bool = false
    
    @FocusState private var isEditorFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private let autoSaveInterval: TimeInterval = 3.0
    private let aiAssistant = AIWritingAssistant()
    
    enum BackgroundStyle: String, CaseIterable {
        case paper = "Paper"
        case gradient = "Gradient"
        case dark = "Dark"
        case cream = "Cream"
        
        var color: Color {
            switch self {
            case .paper:
                return Color(red: 0.99, green: 0.98, blue: 0.97)
            case .gradient:
                return Color.clear
            case .dark:
                return Color(red: 0.1, green: 0.1, blue: 0.12)
            case .cream:
                return Color(red: 1.0, green: 0.98, blue: 0.94)
            }
        }
    }
    
    enum AmbientSound: String, CaseIterable {
        case rain = "Rain"
        case coffeeShop = "Coffee Shop"
        case ocean = "Ocean Waves"
        case forest = "Forest"
        case fireplace = "Fireplace"
        
        var icon: String {
            switch self {
            case .rain: return "cloud.rain"
            case .coffeeShop: return "cup.and.saucer"
            case .ocean: return "water.waves"
            case .forest: return "tree"
            case .fireplace: return "flame"
            }
        }
    }
    
    var body: some View {
        ZStack {
            backgroundView
            
            if isFocusMode {
                focusModeEditor
            } else {
                normalModeEditor
            }
            
            if showingFormattingToolbar {
                FormattingToolbar(
                    selectedRange: $selectedRange,
                    content: $content,
                    isShowing: $showingFormattingToolbar
                )
                .position(formattingToolbarPosition)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                    removal: .opacity
                ))
            }
            
            if showingSlashCommands {
                SlashCommandMenu(
                    query: $slashCommandQuery,
                    isShowing: $showingSlashCommands,
                    onSelect: handleSlashCommand
                )
                .position(slashCommandPosition)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .onAppear(perform: setupEditor)
        .onDisappear(perform: cleanup)
        .onKeyPress(.tab) {
            if showingAISuggestions && !aiSuggestion.isEmpty {
                acceptAISuggestion()
                return .handled
            }
            return .ignored
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch selectedBackground {
        case .paper:
            PaperTextureBackground()
        case .gradient:
            LinearGradient(
                colors: [
                    ModernDesignSystem.Colors.backgroundSecondary,
                    ModernDesignSystem.Colors.backgroundPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark, .cream:
            selectedBackground.color
        }
    }
    
    @ViewBuilder
    private var normalModeEditor: some View {
        VStack(spacing: 0) {
            editorToolbar
            
            Divider()
                .opacity(0.2)
            
            ScrollView {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
                    titleField
                    
                    MarkdownEditor(
                        content: $content,
                        plainText: $plainTextContent,
                        selectedRange: $selectedRange,
                        isTypewriterMode: $isTypewriterMode,
                        isFocused: _isEditorFocused,
                        onTextChange: handleTextChange,
                        onSelectionChange: handleSelectionChange,
                        onSlashCommand: handleSlashTrigger
                    )
                    .frame(minHeight: 400)
                    .padding(.bottom, 100)
                }
                .padding(.horizontal, 40)
                .padding(.top, 32)
            }
            
            editorFooter
        }
    }
    
    @ViewBuilder
    private var focusModeEditor: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 200)
                        
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
                            titleField
                                .id("editor")
                            
                            MarkdownEditor(
                                content: $content,
                                plainText: $plainTextContent,
                                selectedRange: $selectedRange,
                                isTypewriterMode: $isTypewriterMode,
                                isFocused: _isEditorFocused,
                                onTextChange: handleTextChange,
                                onSelectionChange: handleSelectionChange,
                                onSlashCommand: handleSlashTrigger
                            )
                            .frame(minHeight: 400)
                        }
                        .padding(.horizontal, 40)
                        .frame(maxWidth: 700)
                        
                        Spacer(minLength: 300)
                    }
                    .onChange(of: plainTextContent) { _, _ in
                        if isTypewriterMode {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo("editor", anchor: .center)
                            }
                        }
                    }
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        withAnimation(ModernDesignSystem.Animation.spring) {
                            isFocusMode = false
                        }
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(.regularMaterial)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(24)
                }
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var titleField: some View {
        TextField("Untitled", text: $title)
            .font(.system(size: 32, weight: .bold, design: .serif))
            .textFieldStyle(.plain)
            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
    }
    
    @ViewBuilder
    private var editorToolbar: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            Button {
                navigationModel.closeEditor()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(entry?.date.formatted(date: .abbreviated, time: .shortened) ?? "New Entry")
                .font(ModernDesignSystem.Typography.callout)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            Spacer()
            
            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                backgroundPicker
                
                Divider()
                    .frame(height: 20)
                
                ambientSoundPicker
                
                Divider()
                    .frame(height: 20)
                
                Button {
                    withAnimation(ModernDesignSystem.Animation.spring) {
                        isTypewriterMode.toggle()
                    }
                } label: {
                    Image(systemName: "text.aligncenter")
                        .font(.system(size: 14))
                        .foregroundColor(isTypewriterMode ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Typewriter Mode")
                
                Button {
                    withAnimation(ModernDesignSystem.Animation.spring) {
                        isFocusMode.toggle()
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14))
                        .foregroundColor(isFocusMode ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Focus Mode")
                
                Divider()
                    .frame(height: 20)
                
                Button {
                    showingAIPrompts.toggle()
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(showingAIPrompts ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("AI Writing Assistant")
                .popover(isPresented: $showingAIPrompts) {
                    AIWritingAssistantView { prompt in
                        if plainTextContent.isEmpty {
                            plainTextContent = prompt
                        } else {
                            plainTextContent += "\n\n" + prompt
                        }
                        content = AttributedString(plainTextContent)
                        showingAIPrompts = false
                    }
                }
            }
            
            Button("Save") {
                saveEntry()
            }
            .modernButton(.primary)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
    }
    
    @ViewBuilder
    private var backgroundPicker: some View {
        Menu {
            ForEach(BackgroundStyle.allCases, id: \.self) { style in
                Button {
                    withAnimation(ModernDesignSystem.Animation.spring) {
                        selectedBackground = style
                    }
                } label: {
                    Label(style.rawValue, systemImage: selectedBackground == style ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            Image(systemName: "paintbrush")
                .font(.system(size: 14))
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .help("Background Style")
    }
    
    @ViewBuilder
    private var ambientSoundPicker: some View {
        Menu {
            Button {
                isPlayingAmbientSound.toggle()
            } label: {
                Label(
                    isPlayingAmbientSound ? "Stop Sound" : "Play Sound",
                    systemImage: isPlayingAmbientSound ? "speaker.slash" : "speaker.wave.2"
                )
            }
            
            Divider()
            
            ForEach(AmbientSound.allCases, id: \.self) { sound in
                Button {
                    selectedAmbientSound = sound
                    if !isPlayingAmbientSound {
                        isPlayingAmbientSound = true
                    }
                } label: {
                    Label(
                        sound.rawValue,
                        systemImage: selectedAmbientSound == sound ? sound.icon + ".fill" : sound.icon
                    )
                }
            }
        } label: {
            Image(systemName: isPlayingAmbientSound ? "speaker.wave.2" : "speaker")
                .font(.system(size: 14))
                .foregroundColor(isPlayingAmbientSound ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .help("Ambient Sounds")
    }
    
    @ViewBuilder
    private var editorFooter: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            if let mood = detectedMood {
                MoodIndicator(mood: mood, size: .small)
            }
            
            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ModernDesignSystem.Colors.success)
                
                Text("Saved \(lastSaved.formatted(date: .omitted, time: .shortened))")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            if showingAISuggestions && !aiSuggestion.isEmpty {
                Button {
                    acceptAISuggestion()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("Tab to accept")
                            .font(ModernDesignSystem.Typography.caption)
                    }
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text("\(wordCount) words")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text("•")
                    .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                
                Text("\(characterCount) characters")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text("•")
                    .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                
                Text("\(readingTime) min read")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
        )
    }
    
    private func setupEditor() {
        if let entry = entry {
            title = entry.title
            plainTextContent = entry.content
            content = AttributedString(entry.content)
        }
        
        isEditorFocused = true
        startAutoSave()
    }
    
    private func cleanup() {
        autoSaveTimer?.invalidate()
    }
    
    private func startAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { _ in
            Task { @MainActor in
                saveEntry(silent: true)
            }
        }
    }
    
    private func saveEntry(silent: Bool = false) {
        let updatedEntry = JournalEntry(
            id: entry?.id ?? UUID(),
            date: entry?.date ?? Date(),
            title: title.isEmpty ? "Untitled" : title,
            content: plainTextContent,
            mood: detectedMood?.toString()
        )
        
        entry = updatedEntry
        lastSaved = Date()
        
        if !silent {
            onSave?(updatedEntry)
            navigationModel.closeEditor()
        }
    }
    
    private func handleTextChange(_ text: String) {
        plainTextContent = text
        updateMetrics()
        detectMood()
        
        // Trigger AI suggestion after a pause in typing
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            generateAISuggestion()
        }
    }
    
    private func handleSelectionChange(_ range: NSRange?) {
        selectedRange = range
        
        if let range = range, range.length > 0 {
            showingFormattingToolbar = true
        } else {
            showingFormattingToolbar = false
        }
    }
    
    private func handleSlashTrigger(at position: CGPoint) {
        slashCommandPosition = position
        showingSlashCommands = true
        slashCommandQuery = ""
    }
    
    private func handleSlashCommand(_ command: SlashCommand) {
        showingSlashCommands = false
    }
    
    private func updateMetrics() {
        let words = plainTextContent.split(separator: " ").count
        let characters = plainTextContent.count
        let wordsPerMinute = 200.0
        let minutes = Double(words) / wordsPerMinute
        
        wordCount = words
        characterCount = characters
        readingTime = max(1, Int(ceil(minutes)))
    }
    
    private func detectMood() {
        Task {
            await aiAssistant.detectMood(from: plainTextContent)
            if let mood = aiAssistant.detectedMood {
                await MainActor.run {
                    detectedMood = mood
                }
            }
        }
    }
    
    private func generateAISuggestion() {
        guard plainTextContent.count > 10 else { return }
        
        Task {
            await aiAssistant.generateCompletion(for: plainTextContent, cursorPosition: plainTextContent.count)
            let suggestion = aiAssistant.currentSuggestion
            
            await MainActor.run {
                if !suggestion.isEmpty {
                    aiSuggestion = suggestion
                    showingAISuggestions = true
                }
            }
        }
    }
    
    private func acceptAISuggestion() {
        plainTextContent += aiSuggestion
        content = AttributedString(plainTextContent)
        aiSuggestion = ""
        showingAISuggestions = false
    }
}

struct MarkdownEditor: NSViewRepresentable {
    @Binding var content: AttributedString
    @Binding var plainText: String
    @Binding var selectedRange: NSRange?
    @Binding var isTypewriterMode: Bool
    @FocusState var isFocused: Bool
    
    var onTextChange: (String) -> Void
    var onSelectionChange: (NSRange?) -> Void
    var onSlashCommand: (CGPoint) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 0, height: 20)
        
        textView.font = NSFont.systemFont(ofSize: 16)
        textView.defaultParagraphStyle = {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 8
            style.paragraphSpacing = 16
            return style
        }()
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        if textView.string != plainText {
            textView.string = plainText
        }
        
        if isFocused && textView.window?.firstResponder != textView {
            textView.window?.makeFirstResponder(textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        
        init(_ parent: MarkdownEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.plainText = textView.string
            parent.onTextChange(textView.string)
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            parent.selectedRange = range.length > 0 ? range : nil
            parent.onSelectionChange(range.length > 0 ? range : nil)
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                return true
            }
            return false
        }
    }
}

struct FormattingToolbar: View {
    @Binding var selectedRange: NSRange?
    @Binding var content: AttributedString
    @Binding var isShowing: Bool
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            ForEach(FormattingOption.allCases, id: \.self) { option in
                Button {
                    applyFormatting(option)
                } label: {
                    Image(systemName: option.icon)
                        .font(.system(size: 14))
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ModernDesignSystem.Colors.backgroundTertiary)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(ModernDesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                .fill(.regularMaterial)
                .shadow(radius: 8, y: 2)
        )
    }
    
    enum FormattingOption: CaseIterable {
        case bold
        case italic
        case underline
        case strikethrough
        case link
        case quote
        case code
        case list
        
        var icon: String {
            switch self {
            case .bold: return "bold"
            case .italic: return "italic"
            case .underline: return "underline"
            case .strikethrough: return "strikethrough"
            case .link: return "link"
            case .quote: return "quote.opening"
            case .code: return "curlybraces"
            case .list: return "list.bullet"
            }
        }
    }
    
    private func applyFormatting(_ option: FormattingOption) {
    }
}

struct SlashCommand: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let action: () -> Void
}

struct SlashCommandMenu: View {
    @Binding var query: String
    @Binding var isShowing: Bool
    var onSelect: (SlashCommand) -> Void
    
    private let commands = [
        SlashCommand(
            name: "Heading 1",
            icon: "textformat.size.larger",
            description: "Large heading",
            action: {}
        ),
        SlashCommand(
            name: "Heading 2",
            icon: "textformat.size",
            description: "Medium heading",
            action: {}
        ),
        SlashCommand(
            name: "Heading 3",
            icon: "textformat.size.smaller",
            description: "Small heading",
            action: {}
        ),
        SlashCommand(
            name: "Bullet List",
            icon: "list.bullet",
            description: "Create a bullet list",
            action: {}
        ),
        SlashCommand(
            name: "Numbered List",
            icon: "list.number",
            description: "Create a numbered list",
            action: {}
        ),
        SlashCommand(
            name: "Quote",
            icon: "quote.opening",
            description: "Add a quote block",
            action: {}
        ),
        SlashCommand(
            name: "Code Block",
            icon: "curlybraces",
            description: "Add a code block",
            action: {}
        ),
        SlashCommand(
            name: "Divider",
            icon: "minus",
            description: "Add a horizontal divider",
            action: {}
        ),
        SlashCommand(
            name: "Image",
            icon: "photo",
            description: "Insert an image",
            action: {}
        ),
        SlashCommand(
            name: "Table",
            icon: "tablecells",
            description: "Insert a table",
            action: {}
        )
    ]
    
    var filteredCommands: [SlashCommand] {
        if query.isEmpty {
            return commands
        }
        return commands.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if filteredCommands.isEmpty {
                Text("No commands found")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .padding(ModernDesignSystem.Spacing.sm)
            } else {
                ForEach(filteredCommands) { command in
                    Button {
                        onSelect(command)
                    } label: {
                        HStack(spacing: ModernDesignSystem.Spacing.sm) {
                            Image(systemName: command.icon)
                                .font(.system(size: 16))
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(command.name)
                                    .font(ModernDesignSystem.Typography.callout)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                
                                Text(command.description)
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, ModernDesignSystem.Spacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.clear)
                            .onHover { hovering in
                                
                            }
                    )
                }
            }
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                .fill(.regularMaterial)
                .shadow(radius: 12, y: 4)
        )
    }
}

struct PaperTextureBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.99, green: 0.98, blue: 0.97)
            
            Canvas { context, size in
                for _ in 0..<500 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let opacity = Double.random(in: 0.02...0.04)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.gray.opacity(opacity))
                    )
                }
            }
            .allowsHitTesting(false)
            
            GeometryReader { geometry in
                VStack(spacing: 28) {
                    ForEach(0..<100, id: \.self) { _ in
                        Divider()
                            .opacity(0.03)
                    }
                }
            }
        }
    }
}

struct EnhancedJournalEditor_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedJournalEditor(
            entry: .constant(nil),
            isPresented: .constant(true)
        )
        .frame(width: 1000, height: 700)
    }
}