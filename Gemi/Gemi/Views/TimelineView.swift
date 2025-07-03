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
    
    // MARK: - Accessibility
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - Dependencies
    
    /// The journal store containing all entries (injected via @Environment)
    @Environment(JournalStore.self) private var journalStore
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(PerformanceOptimizer.self) private var performanceOptimizer
    @Environment(AccessibilityManager.self) private var accessibilityManager
    @Environment(KeyboardNavigationState.self) private var keyboardNavigation
    
    // MARK: - State
    
    /// Controls the presentation of the AI chat overlay
    @State private var showingChat = false
    
    /// Selected entry for potential future detail view or actions
    @Binding var selectedEntry: JournalEntry?
    
    /// Callback to handle new entry creation
    var onNewEntry: (() -> Void)?
    
    /// Controls the alert for entry deletion confirmation
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: JournalEntry?
    
    /// Search text for filtering entries
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    /// Entry being viewed in floating window
    @State private var viewingEntry: JournalEntry?
    
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
        }
        .toolbar {
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
                    onNewEntry?()
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
                .help(journalStore.isLoading ? "Refreshing entries..." : "Refresh journal entries")
                .disabled(journalStore.isLoading)
            }
        }
        .onAppear {
            Task {
                await journalStore.refreshEntries()
            }
        }
        .sheet(isPresented: $showingChat) {
            // TODO: Replace with actual ChatOverlay when implemented
            chatPlaceholder
        }
        .sheet(item: $viewingEntry) { entry in
            FloatingEntryView(entry: entry)
        }
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    Task {
                        try? await journalStore.deleteEntry(entry)
                        // Haptic feedback on success
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
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedEntries.keys.sorted(by: >), id: \.self) { date in
                    Section {
                        timelineSection(for: date)
                    } header: {
                        timelineSectionHeader(for: date)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await journalStore.refreshEntries()
        }
    }
    
    @ViewBuilder
    private func timelineSection(for date: Date) -> some View {
        VStack(spacing: 24) {
            ForEach(Array(groupedEntries[date]!.enumerated()), id: \.element.id) { index, entry in
                timelineCard(entry: entry, index: index)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, DesignSystem.Spacing.medium) // Add breathing room after header
        .padding(.bottom, 32)
    }
    
    @ViewBuilder
    private func timelineCard(entry: JournalEntry, index: Int) -> some View {
        TimelineCardView(
            entry: entry,
            isSelected: selectedEntry?.id == entry.id,
            action: {
                withAnimation(DesignSystem.Animation.encouragingSpring) {
                    selectedEntry = entry
                    viewingEntry = entry
                }
            },
            onEdit: {
                navigationModel.openEntry(entry)
            },
            onDelete: {
                entryToDelete = entry
                showingDeleteAlert = true
            },
            onDuplicate: {
                // TODO: Duplicate functionality
            },
            onExport: {
                // TODO: Export functionality
            },
            onShare: {
                // TODO: Share functionality
            }
        )
        .id(entry.id)
        .transition(entryTransition)
        .scaleIn(delay: reduceMotion ? 0 : Double(index) * 0.05, from: reduceMotion ? 1 : 0.95)
    }
    
    @ViewBuilder
    private func timelineSectionHeader(for date: Date) -> some View {
        HStack {
            Text(formatDateHeader(date))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
            
            Spacer()
            
            Text("\(groupedEntries[date]!.count) entries")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .horizontal)
        )
    }
    
    private var entryTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .offset(y: 20)),
            removal: .opacity.combined(with: .scale(scale: 0.8)).combined(with: .offset(x: 200))
        )
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
    }
    
    // MARK: - Loading State
    
    @ViewBuilder
    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Warm loading message
                VStack(spacing: DesignSystem.Spacing.small) {
                    DotsLoadingIndicator()
                        .frame(height: 30)
                    
                    Text("Loading your memories...")
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .transition(.opacity)
                }
                .padding(.top, 40)
                
                // Card skeletons with warm styling
                VStack(spacing: 20) {
                    ForEach(0..<3, id: \.self) { index in
                        CardSkeletonView()
                            .frame(height: 140)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: 20)),
                                removal: .opacity
                            ))
                            .animation(
                                DesignSystem.Animation.encouragingSpring.delay(Double(index) * 0.15),
                                value: journalStore.isLoading
                            )
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.backgroundPrimary,
                    DesignSystem.Colors.backgroundSecondary.opacity(0.3),
                    DesignSystem.Colors.backgroundPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
        // Use the beautiful reusable journal illustration
        JournalIllustration(size: 160)
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
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text(getInspirationalGreeting())
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.2, blue: 0.3),
                                Color(red: 0.3, green: 0.3, blue: 0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .multilineTextAlignment(.center)
                
                Text(getInspirationalSubtitle())
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Warm, encouraging description
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("Your thoughts deserve a beautiful, private home where they can flourish. Gemi is here to help you capture life's moments, understand your patterns, and grow through reflection.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .frame(maxWidth: 500)
                
                // Feature pills
                HStack(spacing: 16) {
                    FeaturePill(icon: "lock.shield.fill", text: "100% Private")
                    FeaturePill(icon: "sparkles", text: "AI-Powered")
                    FeaturePill(icon: "heart.fill", text: "Always Here")
                }
                .padding(.top, 8)
            }
        }
    }
    
    @ViewBuilder
    private var inspiringActionSection: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            // Primary inspiration
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("How would you like to begin?")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                // Warm, inviting action buttons
                VStack(spacing: DesignSystem.Spacing.base) {
                    Button {
                        onNewEntry?()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.small) {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 20))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Write your first entry")
                                    .font(DesignSystem.Typography.headline)
                                
                                Text("Start with what's on your mind")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundStyle(.white.opacity(0.9))
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
                                Text("Talk with Gemi")
                                    .font(DesignSystem.Typography.headline)
                                
                                Text("Have a meaningful conversation")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
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
                // Rotating daily prompts
                DailyPromptView()
                    .padding(.horizontal, 40)
            }
        }
    }
    
    // MARK: - Animation State for Empty State
    @State private var breathingAnimation = false
    @State private var cursorBlink = false
    @State private var pencilFloat = false
    @State private var pageHover = false
    
    // MARK: - Loading Animation
    @State private var shimmerPhase: CGFloat = -1
    
    private var shimmeringOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.3),
                    Color.white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width)
            .offset(x: shimmerPhase * geometry.size.width * 2)
            .mask(Rectangle())
            .animation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false),
                value: shimmerPhase
            )
            .onAppear {
                shimmerPhase = 1
            }
        }
    }
    
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

// MARK: - Helper Methods

private extension TimelineView {
    func getInspirationalGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning, writer"
        case 12..<17:
            return "Good afternoon, storyteller"
        case 17..<22:
            return "Good evening, dreamer"
        default:
            return "Hello, night owl"
        }
    }
    
    func getInspirationalSubtitle() -> String {
        let subtitles = [
            "Your story is waiting to be told",
            "Every word you write matters",
            "Today's thoughts, tomorrow's wisdom",
            "Your journal, your sanctuary",
            "Where memories become treasures"
        ]
        return subtitles.randomElement() ?? subtitles[0]
    }
}

// MARK: - Supporting Views

struct FeaturePill: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(text)
                .font(DesignSystem.Typography.caption1)
        }
        .foregroundStyle(DesignSystem.Colors.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct DailyPromptView: View {
    @State private var currentPromptIndex = 0
    
    let prompts = [
        "💭 What made you smile today?",
        "🌟 What are you grateful for right now?",
        "🎯 What's one thing you accomplished today?",
        "💡 What inspired you recently?",
        "🌱 How have you grown this week?",
        "☕ What moment do you want to remember?",
        "✨ What's on your mind right now?"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Need inspiration?")
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
            
            Text(prompts[currentPromptIndex])
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .id(currentPromptIndex)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 10)),
                    removal: .opacity.combined(with: .offset(y: -10))
                ))
            
            Button {
                withAnimation(DesignSystem.Animation.standard) {
                    currentPromptIndex = (currentPromptIndex + 1) % prompts.count
                }
            } label: {
                Text("Another prompt")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Loading Card Placeholder

struct LoadingCardPlaceholder: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 120, height: 14)
            
            // Title skeleton
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 20)
            
            // Content skeleton
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 200, height: 16)
            }
            
            // Tags skeleton
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 60, height: 24)
                }
            }
        }
        .padding(20)
        .background(DesignSystem.Colors.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: DesignSystem.Colors.shadowLight,
            radius: 8,
            y: 4
        )
        .scaleEffect(isAnimating ? 1 : 0.98)
        .opacity(isAnimating ? 1 : 0.8)
        .onAppear {
            withAnimation(
                DesignSystem.Animation.breathing
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}


// MARK: - Previews

#Preview("Timeline with Entries") {
    // For preview, we'll use a mock store if initialization fails
    let store = (try? JournalStore()) ?? JournalStore.preview
    
    return TimelineView(selectedEntry: .constant(nil), onNewEntry: nil)
        .environment(store)
        .frame(width: 800, height: 600)
}

#Preview("Empty Timeline") {
    // For preview, we'll use a mock store if initialization fails
    let emptyStore = (try? JournalStore()) ?? JournalStore.preview
    
    return TimelineView(selectedEntry: .constant(nil), onNewEntry: nil)
        .environment(emptyStore)
        .frame(width: 800, height: 600)
} 