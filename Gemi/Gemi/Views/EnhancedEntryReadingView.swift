import SwiftUI

/// Enhanced reading view with Gemma 3n AI integration
struct EnhancedEntryReadingView: View {
    let entry: JournalEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onChat: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeleteAlert = false
    @State private var contentScale: CGFloat = 1.0
    @State private var showingShareMenu = false
    @State private var showingAIInsights = false
    @State private var aiSummary: String?
    @State private var aiKeyPoints: [String] = []
    @State private var aiSuggestedPrompts: [String] = []
    @State private var isAnalyzing = false
    
    // Reading preferences
    @AppStorage("readingFontSize") private var fontSize: Double = 17
    @AppStorage("readingLineSpacing") private var lineSpacing: Double = 1.5
    
    // AI service
    private let aiCoordinator = GemiAICoordinator.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Done button in upper right
                    HStack {
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Text("Done")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor)
                                        .shadow(color: Color.accentColor.opacity(0.3), radius: 6, x: 0, y: 2)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .keyboardShortcut(.escape, modifiers: [])
                        .keyboardShortcut(.return, modifiers: .command)
                        .help("Close (Esc or ⌘↩)")
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 20)
                    
                    // Article-style header
                    articleHeader
                        .padding(.horizontal, 40)
                        .padding(.top, 0)
                    
                    // Metadata bar
                    metadataBar
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.horizontal, 40)
                    
                    // AI Insights Section (New)
                    if showingAIInsights {
                        aiInsightsSection
                            .padding(.horizontal, 40)
                            .padding(.vertical, 24)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    
                    // Main content
                    contentSection
                        .padding(.horizontal, 40)
                        .padding(.vertical, 32)
                    
                    // Tags section
                    if !entry.tags.isEmpty {
                        tagsSection
                            .padding(.horizontal, 40)
                            .padding(.bottom, 32)
                    }
                }
            }
            .background(Theme.Colors.windowBackground)
            .toolbar {
                toolbarContent
            }
        }
        .frame(minWidth: 700, minHeight: 600)
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
    }
    
    // MARK: - Article Header
    
    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date
            Text(entry.createdAt.formatted(date: .complete, time: .omitted))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            // Title
            Text(entry.displayTitle)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
            
            // Mood indicator
            if let mood = entry.mood {
                HStack(spacing: 8) {
                    Text(mood.emoji)
                        .font(.system(size: 20))
                    Text("Feeling \(mood.rawValue)")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Metadata Bar
    
    private var metadataBar: some View {
        HStack(spacing: 20) {
            // Reading time
            Label("\(entry.readingTime) min read", systemImage: "clock")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            // Word count
            Label("\(entry.wordCount) words", systemImage: "text.alignleft")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            // Last modified
            if entry.modifiedAt > entry.createdAt {
                Label("Edited \(entry.modifiedAt.formatted(.relative(presentation: .named)))", 
                      systemImage: "pencil")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Edit button
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.primary)
            
            // AI Insights Toggle
            Button {
                if !showingAIInsights && aiSummary == nil {
                    generateAIInsights()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingAIInsights.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text(showingAIInsights ? "Hide Insights" : "Show AI Insights")
                    
                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.primaryAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Theme.Colors.primaryAccent.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .disabled(isAnalyzing)
        }
    }
    
    // MARK: - AI Insights Section (New)
    
    @ViewBuilder
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Summary
            if let summary = aiSummary {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Summary", systemImage: "text.quote")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(summary)
                        .font(.system(size: 15))
                        .foregroundColor(.primary.opacity(0.9))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.08))
                        )
                }
            }
            
            // Key Points
            if !aiKeyPoints.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Key Points", systemImage: "list.bullet.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(aiKeyPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 4))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 6)
                                
                                Text(point)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary.opacity(0.85))
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
            
            // Suggested Reflection Prompts
            if !aiSuggestedPrompts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Reflection Prompts", systemImage: "lightbulb")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(aiSuggestedPrompts, id: \.self) { prompt in
                            Button {
                                // Start chat with this prompt
                                onChat()
                            } label: {
                                HStack {
                                    Text(prompt)
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.right.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(Theme.Colors.primaryAccent)
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Theme.Colors.primaryAccent.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            Divider()
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Main content with custom typography
            Text(entry.content)
                .font(.system(size: fontSize, weight: .regular, design: .serif))
                .lineSpacing(fontSize * (lineSpacing - 1))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(entry.tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 11))
                        Text(tag)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Theme.Colors.primaryAccent.opacity(0.1))
                    )
                    .foregroundColor(Theme.Colors.primaryAccent)
                }
            }
        }
    }
    
    // MARK: - Related Actions
    
    private var relatedActionsSection: some View {
        EmptyView() // Removed related actions section
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        
        ToolbarItemGroup(placement: .primaryAction) {
            // Text size controls
            Menu {
                Button {
                    fontSize = max(14, fontSize - 1)
                } label: {
                    Label("Decrease", systemImage: "textformat.size.smaller")
                }
                
                Button {
                    fontSize = 17
                } label: {
                    Label("Reset", systemImage: "textformat.size")
                }
                
                Button {
                    fontSize = min(24, fontSize + 1)
                } label: {
                    Label("Increase", systemImage: "textformat.size.larger")
                }
            } label: {
                Image(systemName: "textformat.size")
            }
            
            
            // More actions
            Menu {
                Button {
                    // Copy to clipboard
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.content, forType: .string)
                } label: {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
                
                Button {
                    showingShareMenu = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Divider()
                
                Button {
                    // TODO: Implement favorite toggle
                } label: {
                    Label(
                        entry.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: entry.isFavorite ? "star.fill" : "star"
                    )
                }
                
                Divider()
                
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete Entry", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    // MARK: - AI Methods
    
    private func generateAIInsights() {
        isAnalyzing = true
        
        Task {
            do {
                // Use the real Gemma 3n API through GemiAICoordinator
                let insights = try await GemiAICoordinator.shared.generateInsights(for: entry)
                
                // Add small delay to prevent layout recursion
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.aiSummary = insights.summary
                        self.aiKeyPoints = insights.keyPoints
                        self.aiSuggestedPrompts = insights.prompts
                        self.isAnalyzing = false
                    }
                }
            } catch {
                // Handle errors gracefully
                await MainActor.run {
                    self.aiSummary = "Unable to generate AI insights at this time. Please ensure Gemma 3n is running."
                    self.aiKeyPoints = [
                        "AI analysis temporarily unavailable",
                        "Check AI model status in settings",
                        "Your journal entry has been saved successfully"
                    ]
                    self.aiSuggestedPrompts = [
                        "Reflect on what brought you to write today",
                        "Consider the emotions present in your entry",
                        "Think about patterns in your recent journal entries"
                    ]
                    self.isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EnhancedEntryReadingView(
        entry: JournalEntry(
            title: "A Beautiful Day",
            content: "Today was absolutely wonderful. The sun was shining, birds were singing, and I felt a deep sense of gratitude for everything in my life. I spent the morning walking through the park, observing the way light filtered through the leaves. There's something magical about these quiet moments of appreciation. I realized that happiness doesn't come from grand gestures, but from noticing and cherishing the small, everyday miracles around us.",
            tags: ["gratitude", "nature", "reflection", "mindfulness"],
            mood: .happy
        ),
        onEdit: {},
        onDelete: {},
        onChat: {}
    )
}