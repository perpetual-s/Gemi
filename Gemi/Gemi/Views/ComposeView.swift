import SwiftUI
import Combine

struct ComposeView: View {
    let entry: JournalEntry?
    let onSave: (JournalEntry) -> Void
    let onCancel: () -> Void
    
    @State private var title = ""
    @State private var content = ""
    @State private var tags: [String] = []
    @State private var tagInput = ""
    @State private var mood: Mood? = nil
    @State private var isSaving = false
    @State private var wordCount = 0
    @State private var lastSaved = Date()
    
    @StateObject private var autoSaveTimer = AutoSaveTimer()
    @FocusState private var isContentFocused: Bool
    
    private let moodOptions = Mood.allCases
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    titleField
                    
                    moodSelector
                    
                    tagsSection
                    
                    contentEditor
                }
                .padding()
            }
            
            Divider()
            
            footer
        }
        .background(Theme.Colors.windowBackground)
        .onAppear {
            loadEntry()
            startAutoSave()
            isContentFocused = true
        }
        .onDisappear {
            autoSaveTimer.stop()
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry == nil ? "New Entry" : "Edit Entry")
                    .font(Theme.Typography.title)
                
                Text(currentDateString)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            Spacer()
            
            if isSaving {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Saving...")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            } else {
                Text("Last saved \(lastSavedString)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
            
            Button("Save", action: saveEntry)
                .buttonStyle(.borderedProminent)
                .disabled(content.isEmpty)
                .keyboardShortcut("s", modifiers: .command)
            
            Button("Save & Close", action: saveAndClose)
                .buttonStyle(.borderedProminent)
                .disabled(content.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                .opacity(0) // Hidden button for keyboard shortcut only
                .frame(width: 0, height: 0)
        }
        .padding()
    }
    
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title (optional)")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            
            TextField("Give your entry a title...", text: $title)
                .textFieldStyle(.plain)
                .font(Theme.Typography.headline)
                .padding(12)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.smallCornerRadius)
        }
    }
    
    private var moodSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How are you feeling?")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(moodOptions, id: \.self) { moodOption in
                        MoodButton(
                            mood: moodOption,
                            isSelected: mood == moodOption,
                            action: { mood = mood == moodOption ? nil : moodOption }
                        )
                    }
                }
            }
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            
            HStack {
                Image(systemName: "tag")
                    .foregroundColor(Theme.Colors.secondaryText)
                
                TextField("Add tags...", text: $tagInput)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        addTag()
                    }
                
                if !tagInput.isEmpty {
                    Button("Add", action: addTag)
                        .buttonStyle(.borderless)
                }
            }
            .padding(12)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.smallCornerRadius)
            
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(tag: tag, onRemove: { removeTag(tag) })
                    }
                }
            }
        }
    }
    
    private var contentEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Content")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Spacer()
                
                Text("\(wordCount) words")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            
            TextEditor(text: $content)
                .font(Theme.Typography.body)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.smallCornerRadius)
                .frame(minHeight: 300)
                .focused($isContentFocused)
                .onChange(of: content) {
                    updateWordCount()
                    autoSaveTimer.trigger()
                }
        }
    }
    
    private var footer: some View {
        HStack {
            Text("⌘S to save • ⌘Enter to save and close")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
            
            Spacer()
        }
        .padding()
    }
    
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    private var lastSavedString: String {
        let interval = Date().timeIntervalSince(lastSaved)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours) hr ago"
        }
    }
    
    private func loadEntry() {
        guard let entry = entry else { return }
        title = entry.title
        content = entry.content
        tags = entry.tags
        mood = entry.mood
        updateWordCount()
    }
    
    private func startAutoSave() {
        autoSaveTimer.onTrigger = { [self] in
            Task { @MainActor in
                await performAutoSave()
            }
        }
    }
    
    private func performAutoSave() async {
        guard !content.isEmpty else { return }
        
        isSaving = true
        
        let updatedEntry = JournalEntry(
            id: entry?.id ?? UUID(),
            createdAt: entry?.createdAt ?? Date(),
            modifiedAt: Date(),
            title: title,
            content: content,
            tags: tags,
            mood: mood
        )
        
        onSave(updatedEntry)
        
        await MainActor.run {
            isSaving = false
            lastSaved = Date()
        }
    }
    
    private func saveEntry() {
        let newEntry = JournalEntry(
            id: entry?.id ?? UUID(),
            createdAt: entry?.createdAt ?? Date(),
            modifiedAt: Date(),
            title: title,
            content: content,
            tags: tags,
            mood: mood
        )
        
        onSave(newEntry)
    }
    
    private func saveAndClose() {
        saveEntry()
        onCancel()
    }
    
    private func addTag() {
        let trimmedTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty, !tags.contains(trimmedTag) else { return }
        
        tags.append(trimmedTag)
        tagInput = ""
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    private func updateWordCount() {
        wordCount = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

struct MoodButton: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(mood.emoji)
                    .font(.title2)
                
                Text(mood.rawValue)
                    .font(Theme.Typography.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                    .fill(isSelected ? Theme.Colors.selectedBackground : Theme.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                    .strokeBorder(isSelected ? Theme.Colors.primaryAccent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(Theme.Typography.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.Colors.primaryAccent.opacity(0.1))
        .foregroundColor(Theme.Colors.primaryAccent)
        .cornerRadius(Theme.smallCornerRadius)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.positions[index].x + bounds.minX,
                                     y: result.positions[index].y + bounds.minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let dimensions = subview.dimensions(in: .unspecified)
                
                if x + dimensions.width > maxWidth, x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                
                x += dimensions.width + spacing
                lineHeight = max(lineHeight, dimensions.height)
            }
            
            size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

@MainActor
class AutoSaveTimer: ObservableObject {
    private var timer: Timer?
    var onTrigger: (() -> Void)?
    
    func trigger() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.onTrigger?()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}