import SwiftUI

/// TimelineView serves as the main interface for displaying journal entries in Gemi.
/// This view provides a chronological list of all journal entries with native macOS styling
/// and navigation controls for creating new entries and accessing the AI chat feature.
///
/// Architecture:
/// - Uses @Environment to access JournalStore (Swift 6 pattern)
/// - Native macOS List component for optimal platform integration
/// - Toolbar with macOS-native button styling
/// - Privacy-focused design with local-only data display
struct TimelineView: View {
    
    // MARK: - Dependencies
    
    /// The journal store containing all entries (injected via @Environment)
    @Environment(JournalStore.self) private var journalStore
    
    // MARK: - State
    
    /// Controls the presentation of the new entry creation view
    @State private var showingNewEntry = false
    
    /// Controls the presentation of the AI chat overlay
    @State private var showingChat = false
    
    /// Selected entry for potential future detail view or actions
    @Binding var selectedEntry: JournalEntry?
    
    /// Controls the alert for entry deletion confirmation
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: JournalEntry?
    
    private var groupedEntries: [Date: [JournalEntry]] {
        Dictionary(grouping: journalStore.entries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                if journalStore.isLoading && journalStore.entries.isEmpty {
                    // Loading state for initial load
                    loadingView
                } else if journalStore.entries.isEmpty {
                    // Empty state when no entries exist
                    emptyStateView
                } else {
                    // Main timeline list
                    timelineList
                }
                
                // Error overlay
                if let errorMessage = journalStore.errorMessage {
                    errorOverlay(message: errorMessage)
                }
            }
            .navigationTitle("Gemi")
            .toolbar(content: {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Talk to Gemi button
                    Button {
                        showingChat = true
                    } label: {
                        Label("Talk to Gemi", systemImage: "message.circle")
                    }
                    .help("Start a conversation with your AI journal companion")
                    
                    // New Entry button
                    Button {
                        showingNewEntry = true
                    } label: {
                        Label("New Entry", systemImage: "square.and.pencil")
                    }
                    .help("Create a new journal entry")
                    .keyboardShortcut("n", modifiers: .command)
                }
                
                ToolbarItemGroup(placement: .secondaryAction) {
                    // Refresh button
                    Button {
                        Task {
                            await journalStore.refreshEntries()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh journal entries")
                    .disabled(journalStore.isLoading)
                }
            })
        }
        .onAppear {
            Task {
                await journalStore.refreshEntries()
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            ComposeView(entry: .constant(nil))
        }
        .sheet(isPresented: $showingChat) {
            // TODO: Replace with actual ChatOverlay when implemented
            chatPlaceholder
        }
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    Task {
                        try? await journalStore.deleteEntry(entry)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this journal entry? This action cannot be undone.")
        }
    }
    
    // MARK: - Timeline List
    
    @ViewBuilder
    private var timelineList: some View {
        List(selection: $selectedEntry) {
            ForEach(groupedEntries.keys.sorted(by: >), id: \.self) { date in
                Section {
                    ForEach(groupedEntries[date]!) { entry in
                        TimelineEntryRow(entry: entry) {
                            // Delete action
                            entryToDelete = entry
                            showingDeleteAlert = true
                        }
                        .tag(entry)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                    }
                } header: {
                    HStack {
                        Text(date, style: .date)
                            .font(DesignSystem.Typography.title3)
                            .elegantSerifStyle()
                            .foregroundStyle(Color(red: 0.529, green: 0.451, blue: 0.373)) // Warm brown for section headers
                            .tracking(1.5)
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium + 4)
                    .padding(.top, DesignSystem.Spacing.large)
                    .padding(.bottom, DesignSystem.Spacing.small)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable {
            await journalStore.refreshEntries()
        }
    }
    
    // MARK: - Loading State
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.base) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(DesignSystem.Colors.primary)
            
            Text("Loading your journal entries...")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.backgroundPrimary)
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: DesignSystem.Spacing.huge)
                
                // Warm, inspiring illustration area
                inspiringJournalIllustration
                
                Spacer(minLength: DesignSystem.Spacing.large)
                
                // Warm, personal welcome message
                inspiringWelcomeContent
                
                Spacer(minLength: DesignSystem.Spacing.extraLarge)
                
                // Encouraging action section
                inspiringActionSection
                
                Spacer(minLength: DesignSystem.Spacing.huge)
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // Warm coffee shop background
            LinearGradient(
                colors: [
                    DesignSystem.Colors.backgroundPrimary,
                    Color(red: 0.98, green: 0.96, blue: 0.92), // Slightly warmer cream
                    DesignSystem.Colors.backgroundPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    @ViewBuilder
    private var inspiringJournalIllustration: some View {
        ZStack {
            // Soft warm glow background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            DesignSystem.Colors.primary.opacity(0.15),
                            DesignSystem.Colors.primary.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(breathingAnimation ? 1.1 : 1.0)
                .animation(DesignSystem.Animation.breathing, value: breathingAnimation)
            
            // Beautiful journal pages stack
            VStack(spacing: -8) {
                // Page 3 (background)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.99, green: 0.97, blue: 0.94))
                    .frame(width: 100, height: 120)
                    .shadow(color: DesignSystem.Colors.shadowLight, radius: 8, x: -2, y: 4)
                    .rotation3DEffect(.degrees(5), axis: (x: 0, y: 1, z: 0))
                    .offset(x: -20, y: 10)
                
                // Page 2 (middle)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.995, green: 0.98, blue: 0.96))
                    .frame(width: 110, height: 130)
                    .shadow(color: DesignSystem.Colors.shadowMedium, radius: 12, x: 0, y: 6)
                    .rotation3DEffect(.degrees(-2), axis: (x: 0, y: 1, z: 0))
                    .offset(x: 5, y: 0)
                
                // Page 1 (front) - the inviting blank page
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.99, blue: 0.97),
                                    Color(red: 0.99, green: 0.98, blue: 0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 140)
                    
                    // Subtle lined paper effect
                    VStack(spacing: 8) {
                        ForEach(0..<6, id: \.self) { _ in
                            Rectangle()
                                .fill(DesignSystem.Colors.primary.opacity(0.1))
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                        }
                    }
                    .offset(y: 10)
                    
                    // Gentle cursor blink to show it's ready
                    Rectangle()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: 2, height: 20)
                        .offset(x: -35, y: -30)
                        .opacity(cursorBlink ? 1.0 : 0.3)
                        .animation(DesignSystem.Animation.heartbeat, value: cursorBlink)
                }
                .shadow(color: DesignSystem.Colors.shadowHeavy, radius: 16, x: 2, y: 8)
                .scaleEffect(pageHover ? 1.05 : 1.0)
                .animation(DesignSystem.Animation.encouragingSpring, value: pageHover)
                .offset(x: 10, y: -10)
            }
            .offset(y: -20)
            
            // Floating pencil with warm glow
            Image(systemName: "pencil")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.8, green: 0.6, blue: 0.3), // Warm wood
                            Color(red: 0.9, green: 0.7, blue: 0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: DesignSystem.Colors.shadowMedium, radius: 8, x: 2, y: 4)
                .rotation3DEffect(.degrees(45), axis: (x: 0, y: 0, z: 1))
                .offset(x: 80, y: -40)
                .scaleEffect(pencilFloat ? 1.1 : 1.0)
                .animation(DesignSystem.Animation.gentleFloat.repeatForever(autoreverses: true), value: pencilFloat)
        }
        .onAppear {
            withAnimation {
                breathingAnimation = true
                cursorBlink = true
                pencilFloat = true
                pageHover = false
            }
        }
    }
    
    @ViewBuilder
    private var inspiringWelcomeContent: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            // Warm, personal headline
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("Your story begins here")
                    .font(DesignSystem.Typography.display)
                    .elegantSerifStyle()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.25, blue: 0.15), // Rich coffee brown
                                Color(red: 0.5, green: 0.35, blue: 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .multilineTextAlignment(.center)
                
                Text("Every great journey starts with a single word")
                    .font(DesignSystem.Typography.title3)
                    .handwrittenStyle()
                    .foregroundStyle(DesignSystem.Colors.primary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            // Warm, encouraging description
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("Welcome to your private sanctuary—a place where thoughts become treasures and moments turn into memories.")
                    .font(DesignSystem.Typography.body)
                    .relaxedReadingStyle()
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                
                Text("Like morning coffee with an understanding friend, Gemi is here to listen, remember, and help you explore the beautiful complexity of your inner world.")
                    .font(DesignSystem.Typography.callout)
                    .diaryTypography()
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 450)
            }
        }
    }
    
    @ViewBuilder
    private var inspiringActionSection: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            // Primary inspiration
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("What would you like to share today?")
                    .font(DesignSystem.Typography.headline)
                    .handwrittenStyle()
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                // Warm, inviting action buttons
                VStack(spacing: DesignSystem.Spacing.base) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.small) {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 20))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Write your first entry")
                                    .font(DesignSystem.Typography.headline)
                                    .handwrittenStyle()
                                
                                Text("Pour your thoughts onto paper")
                                    .font(DesignSystem.Typography.caption1)
                                    .opacity(0.8)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(.horizontal, DesignSystem.Spacing.large)
                        .padding(.vertical, DesignSystem.Spacing.medium + 4)
                    }
                    .gemiPrimaryButton()
                    .frame(maxWidth: 320)
                    
                    Button {
                        showingChat = true
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.small) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 18))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chat with Gemi")
                                    .font(DesignSystem.Typography.headline)
                                    .handwrittenStyle()
                                
                                Text("Start a warm conversation")
                                    .font(DesignSystem.Typography.caption1)
                                    .opacity(0.8)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(.horizontal, DesignSystem.Spacing.large)
                        .padding(.vertical, DesignSystem.Spacing.medium + 4)
                    }
                    .gemiSecondaryButton()
                    .frame(maxWidth: 320)
                }
            }
            
            // Gentle inspiration quotes
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("💭")
                    .font(.system(size: 24))
                
                Text("\"The beautiful thing about writing is that you don't have to get it right the first time, unlike, say, a brain surgeon.\"")
                    .font(DesignSystem.Typography.caption1)
                    .diaryTypography()
                    .italic()
                    .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                
                Text("— Robert Cormier")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.6))
            }
        }
    }
    
    // MARK: - Animation State for Empty State
    @State private var breathingAnimation = false
    @State private var cursorBlink = false
    @State private var pencilFloat = false
    @State private var pageHover = false
    
    // MARK: - Error Overlay
    
    @ViewBuilder
    private func errorOverlay(message: String) -> some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                
                Text(message)
                    .font(.body)
                
                Button("Dismiss") {
                    journalStore.clearError()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 8)
            .padding()
        }
    }
    
    // MARK: - Placeholder Views (TODO: Replace with actual implementations)
    
    @ViewBuilder
    private var chatPlaceholder: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "message.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("Talk to Gemi")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("This will be replaced with the actual ChatOverlay in the next phase.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Close") {
                    showingChat = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Chat with Gemi")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showingChat = false
                    }
                }
            }
        }
    }
}

// MARK: - Timeline Entry Row

/// Beautiful journal page entry with paper-like texture and warm, substantial presence
private struct TimelineEntryRow: View {
    let entry: JournalEntry
    let onDelete: () -> Void
    
    // MARK: - Constants
    
    private let contentPreviewLength = 150
    private let rowHeight: CGFloat = 140 // More substantial height for journal pages
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date header with elegant journal styling
            HStack {
                Text(entry.date, style: .date)
                    .font(DesignSystem.Typography.diaryDate)
                    .elegantSerifStyle()
                    .foregroundStyle(journalDateColor)
                    .tracking(1.2)
                
                Spacer()
                
                Text(entry.date, style: .time)
                    .font(DesignSystem.Typography.footnote)
                    .diaryTypography()
                    .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.8))
                
                // Actions menu - more subtle and integrated
                Menu {
                    Button {
                        // TODO: Add edit functionality in future phase
                    } label: {
                        Label("Edit Entry", systemImage: "pencil")
                    }
                    .disabled(true)
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .opacity(isHovered ? 1.0 : 0.2)
                .scaleEffect(isHovered ? 1.1 : 0.9)
                .animation(DesignSystem.Animation.supportiveEmphasis, value: isHovered)
                .help("Entry options")
            }
            .padding(.horizontal, DesignSystem.Spacing.medium + 4)
            .padding(.top, DesignSystem.Spacing.small + 2)
            .padding(.bottom, DesignSystem.Spacing.tiny)
            
            // Main journal content with handwritten feel
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                // Entry title with personal handwritten style
                Text(entryTitle)
                    .font(DesignSystem.Typography.title3)
                    .handwrittenStyle()
                    .foregroundStyle(journalTitleColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Content preview with relaxed reading style
                Text(contentPreview)
                    .font(DesignSystem.Typography.diaryPreview)
                    .relaxedReadingStyle()
                    .foregroundStyle(journalContentColor)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Footer with word count and subtle details
                HStack {
                    Text("\(wordCount) words")
                        .font(DesignSystem.Typography.caption2)
                        .diaryTypography()
                        .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.7))
                    
                    Spacer()
                    
                    // Subtle paper texture indicator
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.4))
                }
                .padding(.top, DesignSystem.Spacing.tiny)
            }
            .padding(.horizontal, DesignSystem.Spacing.medium + 4)
            .padding(.bottom, DesignSystem.Spacing.medium)
        }
        .frame(minHeight: rowHeight, alignment: .top)
        .background(
            journalPageBackground
        )
        .overlay(
            journalPageBorder
        )
        .journalEntryShadow()
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .rotation3DEffect(
            .degrees(isHovered ? 2 : 0),
            axis: (x: 0.1, y: 0.1, z: 0),
            perspective: 0.8
        )
        .brightness(isHovered ? 0.05 : 0)
        .animation(DesignSystem.Animation.encouragingSpring, value: isHovered)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.warmWelcome) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
    }
    
    // MARK: - Journal Page Styling
    
    private var journalPageBackground: some View {
        ZStack {
            // Base paper background with warm cream color
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium + 2)
                .fill(
                    LinearGradient(
                        colors: [
                            paperBaseColor,
                            paperBaseColor.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Subtle paper texture overlay
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium + 2)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            paperTextureColor.opacity(0.015)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
            
            // Warm inner glow for depth
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium + 2)
                .stroke(
                    LinearGradient(
                        colors: [
                            paperGlowColor.opacity(0.3),
                            Color.clear,
                            paperGlowColor.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
    }
    
    private var journalPageBorder: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium + 2)
            .stroke(
                LinearGradient(
                    colors: [
                        paperBorderColor.opacity(0.6),
                        paperBorderColor.opacity(0.3),
                        paperBorderColor.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
    }
    
    // MARK: - Journal Color Palette
    
    private var paperBaseColor: Color {
        Color(red: 0.992, green: 0.976, blue: 0.952) // Warm cream paper
    }
    
    private var paperTextureColor: Color {
        Color(red: 0.845, green: 0.765, blue: 0.686) // Subtle warm brown texture
    }
    
    private var paperGlowColor: Color {
        Color(red: 0.961, green: 0.890, blue: 0.773) // Warm golden glow
    }
    
    private var paperBorderColor: Color {
        Color(red: 0.871, green: 0.812, blue: 0.749) // Warm beige border
    }
    
    private var journalDateColor: Color {
        Color(red: 0.647, green: 0.565, blue: 0.478) // Warm brown for dates
    }
    
    private var journalTitleColor: Color {
        Color(red: 0.294, green: 0.251, blue: 0.212) // Rich warm charcoal
    }
    
    private var journalContentColor: Color {
        Color(red: 0.412, green: 0.365, blue: 0.322) // Soft warm gray-brown
    }
    
    // MARK: - Computed Properties
    
    private var entryTitle: String {
        let trimmed = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "Untitled Entry"
        }
        
        // Get first line or first 40 characters for title
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? ""
        let title = String(firstLine.prefix(40))
        
        return title.isEmpty ? "Untitled Entry" : (title.count < firstLine.count ? title + "..." : title)
    }
    
    private var contentPreview: String {
        let trimmed = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "No content"
        }
        
        // Skip the first line (used as title) and get preview from remaining content
        let lines = trimmed.components(separatedBy: .newlines)
        let contentLines = lines.count > 1 ? Array(lines.dropFirst()).joined(separator: " ") : trimmed
        
        if contentLines.count <= contentPreviewLength {
            return contentLines
        }
        
        let preview = String(contentLines.prefix(contentPreviewLength))
        // Try to break at a word boundary
        if let lastSpace = preview.lastIndex(of: " ") {
            return String(preview[..<lastSpace]) + "..."
        }
        
        return preview + "..."
    }
    
    private var wordCount: Int {
        entry.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}

// MARK: - Previews

#Preview("Timeline with Entries") {
    let store: JournalStore = {
        do {
            return try JournalStore()
        } catch {
            fatalError("Failed to create JournalStore for preview")
        }
    }()
    
    return TimelineView(selectedEntry: .constant(nil))
        .environment(store)
        .frame(width: 800, height: 600)
}

#Preview("Empty Timeline") {
    let emptyStore: JournalStore = {
        do {
            return try JournalStore()
        } catch {
            fatalError("Failed to create JournalStore for preview")
        }
    }()
    
    return TimelineView(selectedEntry: .constant(nil))
        .environment(emptyStore)
        .frame(width: 800, height: 600)
} 