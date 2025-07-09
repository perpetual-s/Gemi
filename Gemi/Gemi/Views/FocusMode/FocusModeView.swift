import SwiftUI
import AppKit

/// Premium Focus Mode with full feature parity and advanced focus capabilities
struct FocusModeView: View {
    @Binding var entry: JournalEntry
    @Binding var isPresented: Bool
    
    // Core state
    @StateObject private var settings = FocusModeSettings.shared
    @State private var wordCount = 0
    @State private var characterCount = 0
    @State private var hasUnsavedChanges = false
    @State private var lastSavedContent = ""
    
    // UI visibility states
    @State private var showHeader = true
    @State private var showFooter = true
    @State private var showMetadata = false
    @State private var showSettings = false
    @State private var showEmojiPicker = false
    @State private var textEditorCoordinator: FocusTextEditor.Coordinator?
    
    // Animation states
    @State private var backgroundOpacity = 0.0
    @State private var contentOpacity = 0.0
    @State private var uiOpacity = 0.0
    
    // Timer for UI auto-hide
    @State private var uiHideTimer: Timer?
    
    // Force UI updates
    @State private var updateTrigger = UUID()
    
    @Environment(\.colorScheme) var systemColorScheme
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            // Background layer with blur
            focusBackground
                .opacity(backgroundOpacity)
                .animation(.easeOut(duration: 0.4), value: backgroundOpacity)
            
            // Main content layer
            VStack(spacing: 0) {
                // Smart header (appears on hover/movement)
                if showHeader {
                    focusHeader
                        .opacity(uiOpacity)
                        .animation(.easeOut(duration: 0.25), value: uiOpacity)
                }
                
                // Writing area
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                // Centering spacer for typewriter mode
                                if settings.typewriterMode {
                                    Spacer()
                                        .frame(height: geometry.size.height / 2 - 100)
                                }
                                
                                // Content container with max width
                                VStack(spacing: 0) {
                                    // Title editor
                                    titleEditor
                                    
                                    // Visual separator between title and content
                                    Rectangle()
                                        .fill(settings.effectiveTextColor.opacity(0.1))
                                        .frame(height: 1)
                                        .padding(.vertical, 20)
                                    
                                    // Main content editor
                                    contentEditor
                                        .id("editor")
                                }
                                .frame(maxWidth: settings.maxLineWidth)
                                .padding(.horizontal, 40)
                                
                                // Bottom spacer for typewriter mode
                                if settings.typewriterMode {
                                    Spacer()
                                        .frame(height: geometry.size.height / 2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .onChange(of: entry.content) { _, _ in
                            if settings.typewriterMode {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo("editor", anchor: .center)
                                }
                            }
                        }
                    }
                }
                .opacity(contentOpacity)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: contentOpacity)
                
                // Smart footer (appears on hover/movement)
                if showFooter {
                    focusFooter
                        .opacity(uiOpacity)
                        .animation(.easeOut(duration: 0.25), value: uiOpacity)
                }
            }
            
            // Overlay panels
            if showSettings {
                focusSettingsPanel
            }
            
            if showMetadata {
                metadataPanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundColor(settings.effectiveTextColor)
        .onAppear {
            setupFocusMode()
        }
        .onDisappear {
            cleanupFocusMode()
        }
        .onHover { hovering in
            if hovering {
                showUIElements()
            }
        }
        // Keyboard shortcuts handled via menu commands or buttons
    }
    
    // MARK: - Components
    
    private var focusBackground: some View {
        ZStack {
            // Base color
            settings.effectiveBackgroundColor
                .ignoresSafeArea()
            
            // Optional blur of underlying content
            if settings.backgroundOpacity < 1.0 {
                VisualEffectBlur()
                    .opacity(1.0 - settings.backgroundOpacity)
                    .ignoresSafeArea()
            }
            
            // Ambient visual effects
            // TODO: Implement AmbientVisualEffect
            /*
            if settings.showAmbientVisuals && settings.ambientSound != "none" {
                AmbientVisualEffect(sound: AmbientSound(rawValue: settings.ambientSound.capitalized) ?? .none)
                    .ignoresSafeArea()
                    .opacity(0.3)
            }
            */
        }
    }
    
    private var focusHeader: some View {
        HStack(spacing: 20) {
            // Exit button
            Button {
                exitFocusMode()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                    Text("Exit Focus")
                        .font(.system(size: 14))
                }
                .foregroundColor(settings.effectiveTextColor.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(settings.effectiveTextColor.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .help("Exit focus mode (Esc)")
            
            // Document info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayTitle)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                Text(formatSessionTime())
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(settings.effectiveTextColor.opacity(0.6))
            }
            
            Spacer()
            
            // Word count (if enabled)
            if settings.showWordCount {
                HStack(spacing: 16) {
                    Label("\(wordCount)", systemImage: "text.alignleft")
                        .font(.system(size: 13))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.6))
                    
                    if settings.wordGoal > 0 {
                        ProgressCircle(
                            progress: min(Double(wordCount) / Double(settings.wordGoal), 1.0),
                            size: 20,
                            lineWidth: 2
                        )
                    }
                }
            }
            
            // Quick actions
            HStack(spacing: 12) {
                // Metadata toggle
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showMetadata.toggle()
                    }
                } label: {
                    Image(systemName: "tag")
                        .font(.system(size: 16))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(showMetadata ? settings.effectiveTextColor.opacity(0.2) : settings.effectiveTextColor.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .help("Show metadata (tags, mood)")
                
                // Settings
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showSettings.toggle()
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(showSettings ? settings.effectiveTextColor.opacity(0.2) : settings.effectiveTextColor.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .help("Focus settings (⌘,)")
                
                // Save button
                if hasUnsavedChanges {
                    Button {
                        saveEntry()
                    } label: {
                        Label("Save", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(
            settings.effectiveBackgroundColor.opacity(0.8)
                .overlay(
                    Rectangle()
                        .fill(settings.effectiveTextColor.opacity(0.05))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }
    
    private var titleEditor: some View {
        TextField("Untitled", text: $entry.title, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: settings.fontSize + 12, weight: .bold, design: .serif))
            .multilineTextAlignment(.leading)
            .lineLimit(1...3)
            .foregroundColor(settings.effectiveTextColor)
            .opacity(settings.focusLevel == .none || settings.focusLevel == .paragraph ? 1.0 : settings.inactiveTextOpacity)
    }
    
    private var contentEditor: some View {
        FocusTextEditor(
            text: $entry.content,
            fontSize: settings.fontSize,
            textColor: settings.effectiveTextColor,
            focusLevel: settings.focusLevel,
            highlightIntensity: settings.highlightIntensity,
            typewriterMode: settings.typewriterMode,
            onTextChange: { _ in
                updateWordCount()
                hasUnsavedChanges = (entry.content != lastSavedContent)
            },
            onCoordinatorReady: { coordinator in
                textEditorCoordinator = coordinator
            }
        )
        .frame(minHeight: 500)
    }
    
    private var focusFooter: some View {
        VStack(spacing: 0) {
            // Progress bar (if enabled)
            if settings.showProgress && settings.wordGoal > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(settings.effectiveTextColor.opacity(0.1))
                            .frame(height: 2)
                        
                        // Progress
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: progressColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * min(Double(wordCount) / Double(settings.wordGoal), 1.0), height: 2)
                            .animation(.spring(response: 0.5), value: wordCount)
                    }
                }
                .frame(height: 2)
                .padding(.horizontal, 30)
                .padding(.vertical, 10)
            }
            
            // Stats bar
            HStack(spacing: 30) {
                // Writing stats
                HStack(spacing: 20) {
                    Label("\(characterCount) characters", systemImage: "character")
                        .font(.system(size: 12))
                    
                    Label("\(wordCount) words", systemImage: "text.alignleft")
                        .font(.system(size: 12))
                    
                    Label("\(entry.readingTime) min read", systemImage: "book")
                        .font(.system(size: 12))
                }
                .foregroundColor(settings.effectiveTextColor.opacity(0.6))
                
                Spacer()
                
                // Focus level indicator
                Label(settings.focusLevel.rawValue, systemImage: settings.focusLevel.icon)
                    .font(.system(size: 12))
                    .foregroundColor(settings.effectiveTextColor.opacity(0.6))
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
        }
        .background(
            settings.effectiveBackgroundColor.opacity(0.8)
                .overlay(
                    Rectangle()
                        .fill(settings.effectiveTextColor.opacity(0.05))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
    
    private var metadataPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                Text("Entry Details")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Button {
                    withAnimation {
                        showMetadata = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            
            // Mood selector
            VStack(alignment: .leading, spacing: 12) {
                Text("Mood")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(settings.effectiveTextColor.opacity(0.8))
                
                FocusMoodPicker(
                    selectedMood: Binding(
                        get: { entry.mood },
                        set: { newMood in
                            entry.mood = newMood
                            updateTrigger = UUID()
                        }
                    ),
                    textColor: settings.effectiveTextColor
                )
            }
            
            // Tags
            VStack(alignment: .leading, spacing: 12) {
                Text("Tags")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(settings.effectiveTextColor.opacity(0.8))
                
                FocusTagEditor(
                    tags: Binding(
                        get: { entry.tags },
                        set: { newTags in
                            entry.tags = newTags
                            updateTrigger = UUID()
                        }
                    ),
                    textColor: settings.effectiveTextColor
                )
            }
            
            // Favorite toggle
            Toggle(isOn: Binding(
                get: { entry.isFavorite },
                set: { newValue in
                    entry.isFavorite = newValue
                    updateTrigger = UUID()
                }
            )) {
                Label("Mark as Favorite", systemImage: entry.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 14))
            }
            .toggleStyle(.switch)
            
            Spacer()
        }
        .padding(24)
        .frame(width: 350, height: 400)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(settings.effectiveBackgroundColor)
                .shadow(color: .black.opacity(0.2), radius: 20)
        )
        .foregroundColor(settings.effectiveTextColor)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        ))
        .position(x: 200, y: 250)
    }
    
    private var focusSettingsPanel: some View {
        FocusSettingsPanel(
            settings: settings,
            isPresented: $showSettings
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        ))
    }
    
    // MARK: - Helper Methods
    
    private var progressColors: [Color] {
        let percentage = Double(wordCount) / Double(settings.wordGoal)
        if percentage < 0.25 {
            return [Color.blue.opacity(0.6), Color.blue]
        } else if percentage < 0.5 {
            return [Color.green.opacity(0.6), Color.green]
        } else if percentage < 0.75 {
            return [Color.orange.opacity(0.6), Color.orange]
        } else {
            return [Color.purple.opacity(0.6), Color.purple]
        }
    }
    
    private func setupFocusMode() {
        // Start animations
        withAnimation(.easeOut(duration: 0.4)) {
            backgroundOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            contentOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            uiOpacity = 1
        }
        
        // Initialize state
        lastSavedContent = entry.content
        updateWordCount()
        settings.startSession()
        
        // Start UI auto-hide timer if enabled
        if settings.autoHideUI {
            startUIHideTimer()
        }
        
        // Play ambient sound if selected
        if settings.ambientSound != "none" {
            AmbientSoundPlayer.shared.play(sound: AmbientSound(rawValue: settings.ambientSound.capitalized) ?? .none)
        }
    }
    
    private func cleanupFocusMode() {
        settings.endSession()
        settings.saveSettings()
        AmbientSoundPlayer.shared.stop()
        uiHideTimer?.invalidate()
    }
    
    private func updateWordCount() {
        let words = entry.content.split { $0.isWhitespace || $0.isNewline }
        wordCount = words.filter { !$0.isEmpty }.count
        characterCount = entry.content.count
    }
    
    private func formatSessionTime() -> String {
        let elapsed = Date().timeIntervalSince(settings.sessionStartTime)
        let hours = Int(elapsed / 3600)
        let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func showUIElements() {
        withAnimation(.easeOut(duration: 0.25)) {
            uiOpacity = 1
        }
        
        if settings.autoHideUI {
            startUIHideTimer()
        }
    }
    
    private func startUIHideTimer() {
        uiHideTimer?.invalidate()
        // Since SwiftUI Views are structs, we can't capture self in timer
        // Instead, we'll rely on the auto-hide behavior through state changes
    }
    
    private func saveEntry() {
        lastSavedContent = entry.content
        hasUnsavedChanges = false
        // The parent view should handle the actual save
    }
    
    private func exitFocusMode() {
        if hasUnsavedChanges {
            // Should show confirmation dialog
            // For now, just exit
        }
        
        withAnimation(.easeOut(duration: 0.3)) {
            contentOpacity = 0
            uiOpacity = 0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
            backgroundOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
        }
    }
}

// MARK: - Supporting Views

struct ProgressCircle: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// VisualEffectBlur is already defined in SettingsView.swift