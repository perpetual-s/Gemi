//
//  FullComposeView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/3/25.
//

import SwiftUI

/// Full window compose view for creating and editing journal entries
struct FullComposeView: View {
    
    // MARK: - Dependencies
    
    @Environment(JournalStore.self) private var journalStore
    
    // MARK: - State
    
    @Binding var entry: JournalEntry?
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var showingError: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    @State private var showSuccessAnimation = false
    @State private var wordCountPulse = false
    
    // Callbacks
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?
    
    init(entry: Binding<JournalEntry?>, onSave: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self._entry = entry
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Title input
            TextField("Add a title (optional)", text: $title)
                .font(ModernDesignSystem.Typography.title1)
                .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextPrimary)
                .textFieldStyle(.plain)
                .padding(.horizontal, DesignSystem.Spacing.extraLarge)
                .padding(.top, DesignSystem.Spacing.large)
                .padding(.bottom, DesignSystem.Spacing.medium)
            
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.extraLarge)
            
            // Content editor
            ZStack(alignment: .topLeading) {
                // Text editor with encouraging typography
                TextEditor(text: $content)
                    .focused($isTextEditorFocused)
                    .font(ModernDesignSystem.Typography.journal)
                    .scrollContentBackground(.hidden)
                    .padding(DesignSystem.Spacing.extraLarge)
                    .onChange(of: content) { oldValue, newValue in
                        handleContentChange(oldValue: oldValue, newValue: newValue)
                    }
                
                // Warm placeholder
                if content.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                        Text("What's on your mind today?")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundStyle(ModernDesignSystem.Colors.primary.opacity(0.7))
                        
                        Text("Share your thoughts, feelings, or experiences.\nThis is your private space to reflect and express yourself freely.")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundStyle(ModernDesignSystem.Colors.textPlaceholder)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(DesignSystem.Spacing.extraLarge)
                    .allowsHitTesting(false)
                    .opacity(isTextEditorFocused ? 0.6 : 1.0)
                    .animation(DesignSystem.Animation.smooth, value: isTextEditorFocused)
                }
            }
            .frame(maxHeight: .infinity)
            
            // Bottom toolbar
            bottomToolbar
        }
        .background(DesignSystem.Colors.backgroundPrimary)
        .onAppear {
            if let existingEntry = entry {
                title = existingEntry.title
                content = existingEntry.content
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTextEditorFocused = true
            }
        }
        .alert("Error Saving Entry", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred while saving your journal entry.")
        }
        .overlay(successOverlay)
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbar: some View {
        HStack {
            // Word count
            HStack(spacing: DesignSystem.Spacing.tiny) {
                Text("\(wordCount) \(wordCount == 1 ? "word" : "words")")
                    .font(ModernDesignSystem.Typography.caption)
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
            
            Spacer()
            
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
            .disabled(isSaving || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add content to save your entry" : "Save your journal entry")
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(DesignSystem.Spacing.large)
        .background(
            Rectangle()
                .fill(DesignSystem.Colors.backgroundSecondary.opacity(0.3))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(DesignSystem.Colors.divider.opacity(0.3))
                        .frame(height: 1)
                }
        )
    }
    
    // MARK: - Success Overlay
    
    @ViewBuilder
    private var successOverlay: some View {
        if showSuccessAnimation {
            ZStack {
                // Background blur
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                
                // Success checkmark animation
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(DesignSystem.Colors.success)
                        .scaleEffect(showSuccessAnimation ? 1.0 : 0.5)
                        .animation(
                            DesignSystem.Animation.playfulBounce.delay(0.1),
                            value: showSuccessAnimation
                        )
                    
                    Text("Entry Saved!")
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .opacity(showSuccessAnimation ? 1.0 : 0.0)
                        .animation(
                            DesignSystem.Animation.standard.delay(0.2),
                            value: showSuccessAnimation
                        )
                }
            }
            .transition(.asymmetric(
                insertion: .opacity,
                removal: .opacity
            ))
        }
    }
    
    // MARK: - Helper Properties
    
    private var wordCount: Int {
        content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    private var wordCountColor: Color {
        switch wordCount {
        case 0:
            return DesignSystem.Colors.textTertiary
        case 1...10:
            return DesignSystem.Colors.textSecondary
        case 11...50:
            return DesignSystem.Colors.primary.opacity(0.8)
        case 51...100:
            return DesignSystem.Colors.primary
        default:
            return DesignSystem.Colors.success
        }
    }
    
    // MARK: - Actions
    
    private func handleContentChange(oldValue: String, newValue: String) {
        let oldWordCount = oldValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        
        let newWordCount = wordCount
        
        if newWordCount > oldWordCount && newWordCount > 0 {
            withAnimation(DesignSystem.Animation.playfulBounce) {
                wordCountPulse = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(DesignSystem.Animation.writingFlow) {
                    wordCountPulse = false
                }
            }
        }
    }
    
    @MainActor
    private func saveEntry() async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSaving = true
        
        do {
            if let existingEntry = entry {
                // Update existing entry with new title and content
                var updatedEntry = existingEntry
                updatedEntry.title = title
                updatedEntry.content = content
                try await journalStore.updateEntry(updatedEntry)
                entry = updatedEntry
            } else {
                // Create new entry with title and content
                let newEntry = JournalEntry(title: title, content: content)
                try await journalStore.addEntry(newEntry)
            }
            
            print("Journal entry saved successfully")
            
            // Show success animation
            withAnimation(DesignSystem.Animation.playfulBounce) {
                showSuccessAnimation = true
            }
            
            // Haptic feedback
            NSSound.beep()
            
            // Delay before calling onSave
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            if let onSave = onSave {
                onSave()
            }
        } catch {
            print("Failed to save journal entry: \(error)")
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isSaving = false
    }
}

// MARK: - Preview

#Preview("Full Compose") {
    FullComposeView(entry: .constant(nil))
        .frame(width: 1000, height: 700)
        .environment(try! JournalStore())
}