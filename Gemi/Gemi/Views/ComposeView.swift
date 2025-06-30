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
    
    init(entry: Binding<JournalEntry?>, onSave: (() -> Void)? = nil) {
        self._entry = entry
        self.onSave = onSave
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
    
    // MARK: - Constants
    
    private let placeholderText = "What's on your mind today?\n\nShare your thoughts, feelings, or experiences. This is your private space to reflect and express yourself freely."
    private let minimumContentLength = 1
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main text editor
                textEditorSection
                
                // Bottom toolbar with actions
                if !isFocusMode {
                    bottomToolbar
                }
            }
            .navigationTitle(isFocusMode ? "" : "New Entry")
            .navigationSubtitle(isFocusMode ? "" : entryWordCount)
            .toolbar {
                if !isFocusMode {
                    toolbarContent
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
    }
    
    // MARK: - Text Editor Section
    
    @ViewBuilder
    private var textEditorSection: some View {
        ZStack(alignment: .topLeading) {
            // Text editor with clean background
            TextEditor(text: $content)
                .focused($isTextEditorFocused)
                .font(DesignSystem.Typography.body)
                .lineSpacing(6)
                .scrollContentBackground(.hidden) // Hide default background
                .padding(DesignSystem.Spacing.large)
            
            // Placeholder text (shown when content is empty)
            if content.isEmpty {
                Text(placeholderText)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPlaceholder)
                    .padding(DesignSystem.Spacing.large + 4) // Account for TextEditor padding
                    .allowsHitTesting(false) // Allow clicks to pass through to TextEditor
            }
        }
        .background(Color.clear) // Use transparent background for floating panel integration
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
                // Recording indicator
                if speechService.isRecording {
                    HStack(spacing: DesignSystem.Spacing.tiny) {
                        Circle()
                            .fill(DesignSystem.Colors.error)
                            .frame(width: 8, height: 8)
                            .scaleEffect(speechService.isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speechService.isRecording)
                        
                        Text("Recording...")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(DesignSystem.Colors.error)
                    }
                }
                
                // Word count
                Text(entryWordCount)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                
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
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Cancel button
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape)
        }
        
        // Save button (secondary)
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                Task {
                    await saveEntry()
                }
            }
            .disabled(isSaving || !canSave)
            .keyboardShortcut("s", modifiers: .command)
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button(action: {
                withAnimation {
                    isFocusMode.toggle()
                }
            }) {
                Label("Focus Mode", systemImage: isFocusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns the current word count of the entry
    private var entryWordCount: String {
        let wordCount = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        
        return "\(wordCount) \(wordCount == 1 ? "word" : "words")"
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
            onSave?()
            
            // Close the compose view after successful save
            dismiss()
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
    let store: JournalStore = {
        do {
            return try JournalStore()
        } catch {
            fatalError("Failed to create JournalStore for preview")
        }
    }()
    
    return ComposeView(entry: .constant(JournalEntry(content: "")))
        .environment(store)
        .frame(width: 700, height: 500)
}

#Preview("Compose View with Content") {
    let store: JournalStore = {
        do {
            return try JournalStore()
        } catch {
            fatalError("Failed to create JournalStore for preview")
        }
    }()
    
    return ComposeView(entry: .constant(JournalEntry(content: "This is a test entry.")))
        .environment(store)
        .frame(width: 700, height: 500)
} 