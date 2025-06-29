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
    
    /// The content being composed by the user
    @State private var entryContent: String = ""
    
    /// Loading state for save operation
    @State private var isSaving: Bool = false
    
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
                bottomToolbar
            }
            .navigationTitle("New Entry")
            .navigationSubtitle(entryWordCount)
            .toolbar {
                toolbarContent
            }
            .alert("Error Saving Entry", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred while saving your journal entry.")
            }
            .onAppear {
                // Focus the text editor when the view appears
                isTextEditorFocused = true
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
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .stroke(.separator, lineWidth: 1)
            
            // Text editor
            TextEditor(text: $entryContent)
                .focused($isTextEditorFocused)
                .font(.body)
                .lineSpacing(4)
                .scrollContentBackground(.hidden) // Hide default background
                .padding(16)
            
            // Placeholder text (shown when content is empty)
            if entryContent.isEmpty {
                Text(placeholderText)
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(20) // Slightly more padding to align with TextEditor
                    .allowsHitTesting(false) // Allow clicks to pass through to TextEditor
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbar: some View {
        HStack(spacing: 16) {
            // Multimodal input buttons (left side)
            HStack(spacing: 12) {
                // Microphone button for speech-to-text
                Button {
                    Task {
                        await handleMicrophoneButtonTap()
                    }
                } label: {
                    Label("Dictate", systemImage: microphoneButtonIcon)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(speechService.isRecording ? .red : .primary)
                }
                .buttonStyle(.borderless)
                .help(speechService.isRecording ? "Stop dictation" : "Start voice dictation")
                .disabled(isSaving)
                
                // Image attachment button
                Button {
                    showingImageImporter = true
                } label: {
                    Label("Add Image", systemImage: "photo.circle.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Attach image")
                .disabled(isSaving)
            }
            
            Spacer()
            
            // Entry info and actions (right side)
            HStack(spacing: 16) {
                // Recording indicator
                if speechService.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                            .scaleEffect(speechService.isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speechService.isRecording)
                        
                        Text("Recording...")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                // Word count
                Text(entryWordCount)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Save button
                Button {
                    Task {
                        await saveEntry()
                    }
                } label: {
                    if isSaving {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Saving...")
                        }
                    } else {
                        Label("Save Entry", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || !canSave)
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
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
    }
    
    // MARK: - Computed Properties
    
    /// Returns the current word count of the entry
    private var entryWordCount: String {
        let wordCount = entryContent
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        
        return "\(wordCount) \(wordCount == 1 ? "word" : "words")"
    }
    
    /// Returns true if the entry can be saved
    private var canSave: Bool {
        entryContent.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumContentLength
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
            try await journalStore.addEntry(content: entryContent)
            
            print("Journal entry saved successfully")
            
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
        if !entryContent.isEmpty && !entryContent.hasSuffix(" ") && !entryContent.hasSuffix("\n") {
            entryContent += " "
        }
        
        entryContent += trimmedTranscription
        
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
        if !entryContent.isEmpty && !entryContent.hasSuffix("\n") && !entryContent.hasSuffix(" ") {
            entryContent += "\n\n"
        } else if !entryContent.isEmpty && entryContent.hasSuffix("\n") && !entryContent.hasSuffix("\n\n") {
            entryContent += "\n"
        }
        
        entryContent += imagePlaceholder
        
        // Add spacing after the placeholder for continued writing
        if !entryContent.hasSuffix("\n") {
            entryContent += "\n\n"
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
    
    return ComposeView()
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
    
    return ComposeView()
        .environment(store)
        .frame(width: 700, height: 500)
} 