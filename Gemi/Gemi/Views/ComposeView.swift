import SwiftUI
import UniformTypeIdentifiers

/// ComposeView provides the journal entry creation and editing interface for Gemi.
/// This view offers a clean, distraction-free writing environment with multimodal input support.
///
/// Features:
/// - Rich text editing with TextEditor
/// - Speech-to-text functionality with local processing
/// - Image attachment button (placeholder for future multimodal support)
/// - Native macOS styling and keyboard shortcuts
/// - Privacy-first design with local-only processing
struct ComposeView: View {
    
    // MARK: - Dependencies
    
    /// The journal store for saving entries (injected via @Environment)
    @Environment(JournalStore.self) private var journalStore
    
    /// Dismissal action for closing the compose view
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    /// The entry to be edited (if any)
    @Binding var entry: JournalEntry?
    
    /// Local editable content
    @State private var content: String = ""
    
    /// Optional callback when entry is saved (for parent state management)
    var onSave: (() -> Void)?
    
    /// Loading state for save operation
    @State private var isSaving: Bool = false
    
    // MARK: - Initialization
    
    /// Callback when user cancels the compose view
    var onCancel: (() -> Void)?
    
    init(entry: Binding<JournalEntry?>, onSave: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self._entry = entry
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    /// Error state for displaying save errors
    @State private var errorMessage: String?
    
    /// Controls the presentation of error alerts
    @State private var showingError: Bool = false
    
    /// Focus state for the text editor
    @FocusState private var isTextEditorFocused: Bool
    
    /// Speech recognition service for voice dictation
    @State private var speechService = SpeechRecognitionService()
    
    /// Controls the presentation of permission request alerts
    @State private var showingPermissionAlert: Bool = false
    
    /// Controls the presentation of file importer for image selection
    @State private var showingImageImporter: Bool = false
    
    /// Currently selected image file (if any)
    @State private var selectedImageURL: URL?
    
    @State private var isFocusMode = false
    
    // MARK: - Encouraging Animation State
    
    /// Writing encouragement state
    @State private var isWriting = false
    @State private var wordCountPulse = false
    @State private var editorGlow = false
    @State private var welcomePulse = 1.0
    
    // MARK: - Constants
    
    private let placeholderText = "What's on your mind today?\n\nShare your thoughts, feelings, or experiences. This is your private space to reflect and express yourself freely."
    private let minimumContentLength = 1
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Main text editor
            textEditorSection
            
            // Bottom toolbar with actions
            if !isFocusMode {
                bottomToolbar
            }
        }
        .alert("Error Saving Entry", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred while saving your journal entry.")
        }
        .onAppear {
                // Initialize content from entry if editing, otherwise start fresh
                if let existingEntry = entry {
                    content = existingEntry.content
                } else {
                    content = ""
                }
                
                // Focus the text editor when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextEditorFocused = true
                }
            }
            .onDisappear {
                // Clean up speech recognition when view disappears
                if speechService.isRecording {
                    speechService.stopRecording()
                }
            }
            .onChange(of: speechService.currentTranscription) { oldValue, newValue in
                // Live transcription preview (optional - for real-time feedback)
                // For now, we'll just wait for the user to stop recording
            }
            .onChange(of: speechService.errorMessage) { oldValue, newValue in
                if let error = newValue {
                    errorMessage = error
                    showingError = true
                    speechService.clearError()
                }
            }
            .fileImporter(
                isPresented: $showingImageImporter,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                handleImageSelection(result)
            }
    }
    
    // MARK: - Text Editor Section
    
    @ViewBuilder
    private var textEditorSection: some View {
        ZStack(alignment: .topLeading) {
            // Encouraging writing environment background
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusLarge)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.backgroundPrimary,
                            DesignSystem.Colors.backgroundPrimary.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusLarge)
                        .stroke(
                            DesignSystem.Colors.primary.opacity(
                                isTextEditorFocused ? 0.3 : 
                                editorGlow ? 0.2 : 0.1
                            ),
                            lineWidth: 2
                        )
                )
                .animation(DesignSystem.Animation.encouragingSpring, value: isTextEditorFocused)
                .animation(DesignSystem.Animation.breathing, value: editorGlow)
            
            // Text editor with encouraging typography
            TextEditor(text: $content)
                .focused($isTextEditorFocused)
                .font(DesignSystem.Typography.diaryBody)
                .relaxedReadingStyle()
                .scrollContentBackground(.hidden)
                .padding(DesignSystem.Spacing.large + 8)
                .onChange(of: content) { oldValue, newValue in
                    handleContentChange(oldValue: oldValue, newValue: newValue)
                }
                .onTapGesture {
                    withAnimation(DesignSystem.Animation.warmWelcome) {
                        isTextEditorFocused = true
                        editorGlow = true
                    }
                }
            
            // Warm, encouraging placeholder
            if content.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    Text("What's on your mind today?")
                        .font(DesignSystem.Typography.title3)
                        .elegantSerifStyle()
                        .foregroundStyle(DesignSystem.Colors.primary.opacity(0.7))
                        .scaleEffect(welcomePulse)
                    
                    Text("Share your thoughts, feelings, or experiences.\nThis is your private space to reflect and express yourself freely.")
                        .font(DesignSystem.Typography.body)
                        .diaryTypography()
                        .foregroundStyle(DesignSystem.Colors.textPlaceholder)
                        .multilineTextAlignment(.leading)
                }
                .padding(DesignSystem.Spacing.large + 8)
                .allowsHitTesting(false)
                .opacity(isTextEditorFocused ? 0.6 : 1.0)
                .animation(DesignSystem.Animation.smooth, value: isTextEditorFocused)
                .onAppear {
                    withAnimation(DesignSystem.Animation.breathing) {
                        welcomePulse = 1.05
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color.clear)
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbar: some View {
        HStack(spacing: DesignSystem.Spacing.base) {
            // Multimodal input buttons (left side)
            HStack(spacing: DesignSystem.Spacing.medium) {
                // Microphone button for speech-to-text
                Button {
                    Task {
                        await handleMicrophoneButtonTap()
                    }
                } label: {
                    Label("Dictate", systemImage: microphoneButtonIcon)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(speechService.isRecording ? DesignSystem.Colors.error : DesignSystem.Colors.textSecondary)
                }
                .gemiSubtleButton()
                .help(speechService.isRecording ? "Stop dictation" : "Start voice dictation")
                .disabled(isSaving)
                
                // Image attachment button
                Button {
                    showingImageImporter = true
                } label: {
                    Label("Add Image", systemImage: "photo.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .gemiSubtleButton()
                .help("Attach image")
                .disabled(isSaving)
            }
            
            Spacer()
            
            // Entry info and actions (right side)
            HStack(spacing: DesignSystem.Spacing.base) {
                // Cancel button
                Button("Cancel") {
                    if let onCancel = onCancel {
                        onCancel()
                    } else {
                        dismiss()
                    }
                }
                .gemiSecondaryButton()
                .keyboardShortcut(.escape)
                
                // Encouraging recording indicator
                if speechService.isRecording {
                    HStack(spacing: DesignSystem.Spacing.small) {
                        ZStack {
                            // Outer pulse ring
                            Circle()
                                .stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 3)
                                .frame(width: 20, height: 20)
                                .scaleEffect(speechService.isRecording ? 1.5 : 1.0)
                                .opacity(speechService.isRecording ? 0.0 : 1.0)
                                .animation(DesignSystem.Animation.breathing, value: speechService.isRecording)
                            
                            // Inner recording dot
                            Circle()
                                .fill(DesignSystem.Colors.primary)
                                .frame(width: 8, height: 8)
                                .scaleEffect(speechService.isRecording ? 1.3 : 1.0)
                                .animation(DesignSystem.Animation.heartbeat, value: speechService.isRecording)
                        }
                        
                        Text("Listening to your voice...")
                            .font(DesignSystem.Typography.caption1)
                            .diaryTypography()
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Encouraging word count
                HStack(spacing: DesignSystem.Spacing.tiny) {
                    Text(entryWordCount)
                        .font(DesignSystem.Typography.caption1)
                        .handwrittenStyle()
                        .foregroundStyle(wordCountColor)
                        .scaleEffect(wordCountPulse ? 1.2 : 1.0)
                        .animation(DesignSystem.Animation.supportiveEmphasis, value: wordCountPulse)
                    
                    if wordCount > 0 {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(DesignSystem.Colors.primary.opacity(0.6))
                            .scaleEffect(wordCountPulse ? 1.3 : 1.0)
                            .animation(DesignSystem.Animation.playfulBounce, value: wordCountPulse)
                    }
                }
                
                // Save button
                Button {
                    Task {
                        await saveEntry()
                    }
                } label: {
                    if isSaving {
                        HStack(spacing: DesignSystem.Spacing.small) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Saving...")
                        }
                    } else {
                        Label("Save Entry", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .gemiPrimaryButton(isLoading: isSaving)
                .disabled(isSaving || !canSave)
                .keyboardShortcut("s", modifiers: .command)
                .frame(maxWidth: 140)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.large)
        .padding(.vertical, DesignSystem.Spacing.base)
        .background(
            Rectangle()
                .fill(DesignSystem.Colors.backgroundSecondary.opacity(0.8))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(DesignSystem.Colors.divider.opacity(0.3))
                        .frame(height: 1)
                }
        )
    }
    
    // MARK: - Computed Properties
    
    /// Returns the current word count of the entry
    private var entryWordCount: String {
        return "\(wordCount) \(wordCount == 1 ? "word" : "words")"
    }
    
    /// Returns the numerical word count
    private var wordCount: Int {
        content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    /// Returns encouraging color for word count based on progress
    private var wordCountColor: Color {
        switch wordCount {
        case 0:
            return DesignSystem.Colors.textTertiary
        case 1...10:
            return DesignSystem.Colors.primary.opacity(0.7)
        case 11...50:
            return DesignSystem.Colors.primary
        case 51...100:
            return DesignSystem.Colors.success.opacity(0.8)
        default:
            return DesignSystem.Colors.success
        }
    }
    
    /// Returns true if the entry can be saved
    private var canSave: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumContentLength
    }
    
    /// Returns the appropriate icon for the microphone button based on recording state
    private var microphoneButtonIcon: String {
        if speechService.isRecording {
            return "mic.fill"
        } else {
            return "mic.circle.fill"
        }
    }
    
    // MARK: - Encouraging Interaction Handlers
    
    /// Handles content changes with encouraging feedback
    @MainActor
    private func handleContentChange(oldValue: String, newValue: String) {
        let oldWordCount = oldValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        
        let newWordCount = wordCount
        
        // Trigger encouraging animations on word milestones
        if newWordCount > oldWordCount {
            withAnimation(DesignSystem.Animation.supportiveEmphasis) {
                wordCountPulse = true
            }
            
            // Reset pulse after brief moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(DesignSystem.Animation.writingFlow) {
                    wordCountPulse = false
                }
            }
            
            // Special encouragement at milestones
            if newWordCount == 10 || newWordCount == 25 || newWordCount == 50 || newWordCount == 100 {
                withAnimation(DesignSystem.Animation.playfulBounce) {
                    // Could add special celebration here
                }
            }
        }
        
        // Update writing state
        isWriting = !newValue.isEmpty
        
        // Maintain editor glow while actively writing
        if !newValue.isEmpty && !editorGlow {
            withAnimation(DesignSystem.Animation.encouragingSpring) {
                editorGlow = true
            }
        } else if newValue.isEmpty && editorGlow {
            withAnimation(DesignSystem.Animation.cozySettle) {
                editorGlow = false
            }
        }
    }
    
    // MARK: - Actions
    
    /// Saves the journal entry to the database
    @MainActor
    private func saveEntry() async {
        guard canSave else { return }
        
        isSaving = true
        
        do {
            if let existingEntry = entry {
                // Update existing entry
                try await journalStore.updateEntry(existingEntry, content: content)
                
                // Update the binding to reflect changes
                entry?.content = content
            } else {
                // Create new entry
                try await journalStore.addEntry(content: content)
            }
            
            print("Journal entry saved successfully")
            
            // Call onSave callback if provided
            if let onSave = onSave {
                onSave()
            } else {
                // Only dismiss if we're in a sheet context (no custom onSave)
                dismiss()
            }
        } catch {
            print("Failed to save journal entry: \(error)")
            
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isSaving = false
    }
    
    /// Handles microphone button tap for speech-to-text
    @MainActor
    private func handleMicrophoneButtonTap() async {
        if speechService.isRecording {
            // Stop recording and append transcription
            speechService.stopRecording()
            
            // Give a moment for final transcription to process
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            let transcription = speechService.consumeTranscription()
            if !transcription.isEmpty {
                appendTranscriptionToContent(transcription)
            }
        } else {
            // Check permissions and start recording
            await startSpeechRecognition()
        }
    }
    
    /// Starts speech recognition with permission handling
    @MainActor
    private func startSpeechRecognition() async {
        // Check if permissions are already granted
        if speechService.isAvailable {
            await startRecording()
            return
        }
        
        // Request permissions if not available
        if speechService.authorizationStatus == .notDetermined || 
           speechService.microphoneAuthorizationStatus == false {
            await speechService.requestPermissions()
        }
        
        // Check permissions after request
        if speechService.isAvailable {
            await startRecording()
        } else {
            showPermissionAlert()
        }
    }
    
    /// Starts the actual recording process
    @MainActor
    private func startRecording() async {
        do {
            try await speechService.startRecording()
        } catch {
            print("Failed to start recording: \(error)")
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    /// Shows permission alert for speech recognition
    @MainActor
    private func showPermissionAlert() {
        errorMessage = "Speech recognition requires microphone and speech recognition permissions. Please enable them in System Preferences > Privacy & Security."
        showingError = true
    }
    
    /// Appends transcribed text to the entry content
    @MainActor
    private func appendTranscriptionToContent(_ transcription: String) {
        let trimmedTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscription.isEmpty else { return }
        
        // Add appropriate spacing
        if !content.isEmpty && !content.hasSuffix(" ") && !content.hasSuffix("\n") {
            content += " "
        }
        
        content += trimmedTranscription
        
        print("Appended transcription: \(trimmedTranscription)")
    }
    
    /// Handles image file selection from the file importer
    @MainActor
    private func handleImageSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let imageURL = urls.first else { return }
            selectedImageURL = imageURL
            insertImagePlaceholder(for: imageURL)
            
        case .failure(let error):
            print("Image selection failed: \(error.localizedDescription)")
            errorMessage = "Failed to select image: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    /// Inserts a markdown-style image placeholder into the entry content
    @MainActor
    private func insertImagePlaceholder(for imageURL: URL) {
        let fileName = imageURL.lastPathComponent
        let imagePlaceholder = "[Image: \(fileName)]"
        
        // Add appropriate spacing before the image placeholder
        if !content.isEmpty && !content.hasSuffix("\n") && !content.hasSuffix(" ") {
            content += "\n\n"
        } else if !content.isEmpty && content.hasSuffix("\n") && !content.hasSuffix("\n\n") {
            content += "\n"
        }
        
        content += imagePlaceholder
        
        // Add spacing after the placeholder for continued writing
        if !content.hasSuffix("\n") {
            content += "\n\n"
        }
        
        print("Inserted image placeholder: \(imagePlaceholder)")
    }
}

// MARK: - Previews

#Preview("Empty Compose View") {
    // For preview, we'll use a mock store if initialization fails
    let store = (try? JournalStore()) ?? JournalStore.preview
    
    return ComposeView(entry: .constant(nil))
        .environment(store)
        .frame(width: 700, height: 500)
}

#Preview("Compose View with Content") {
    // For preview, we'll use a mock store if initialization fails
    let store = (try? JournalStore()) ?? JournalStore.preview
    
    return ComposeView(entry: .constant(JournalEntry(title: "Test Entry", content: "This is a test entry.")))
        .environment(store)
        .frame(width: 700, height: 500)
} 