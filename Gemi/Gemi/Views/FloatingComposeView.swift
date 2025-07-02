//
//  FloatingComposeView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import SwiftUI

/// A beautiful floating window compose view with cozy coffee shop warmth
struct FloatingComposeView: View {
    
    // MARK: - Dependencies
    
    @Environment(JournalStore.self) private var journalStore
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @Binding var entry: JournalEntry?
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var showingError: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    
    // Animation states
    @State private var isWriting = false
    @State private var wordCountPulse = false
    @State private var editorGlow = false
    
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
            // Floating header
            floatingHeader
            
            // Main editor
            editorSection
            
            // Bottom actions
            bottomActions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusLarge)
                .fill(DesignSystem.Colors.backgroundPrimary)
                .shadow(
                    color: DesignSystem.Colors.shadowMedium,
                    radius: 20,
                    x: 0,
                    y: 10
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
    }
    
    // MARK: - Floating Header
    
    @ViewBuilder
    private var floatingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                Text(entry != nil ? "Edit Entry" : "New Entry")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextPrimary)
                
                Text("Share your thoughts in this private, safe space")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextSecondary)
            }
            
            Spacer()
            
            // Close button
            Button {
                withAnimation(DesignSystem.Animation.cozySettle) {
                    if let onCancel = onCancel {
                        onCancel()
                    } else {
                        dismiss()
                    }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.hover.opacity(0.5))
                    )
            }
            .buttonStyle(.plain)
            .help("Close editor (Esc)")
        }
        .padding(DesignSystem.Spacing.large)
        .background(
            Rectangle()
                .fill(DesignSystem.Colors.backgroundSecondary.opacity(0.5))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignSystem.Colors.divider.opacity(0.3))
                        .frame(height: 1)
                }
        )
    }
    
    // MARK: - Editor Section
    
    @ViewBuilder
    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title input
            TextField("Add a title (optional)", text: $title)
                .font(ModernDesignSystem.Typography.title2)
                .foregroundStyle(ModernDesignSystem.Colors.adaptiveTextPrimary)
                .textFieldStyle(.plain)
                .padding(.horizontal, DesignSystem.Spacing.large)
                .padding(.top, DesignSystem.Spacing.medium)
                .padding(.bottom, DesignSystem.Spacing.small)
            
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.large)
            
            // Content editor
            ZStack(alignment: .topLeading) {
                // Text editor with encouraging typography
                TextEditor(text: $content)
                    .focused($isTextEditorFocused)
                    .font(ModernDesignSystem.Typography.journal)
                    .scrollContentBackground(.hidden)
                    .padding(DesignSystem.Spacing.large)
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
                    .padding(DesignSystem.Spacing.large)
                    .allowsHitTesting(false)
                    .opacity(isTextEditorFocused ? 0.6 : 1.0)
                    .animation(DesignSystem.Animation.smooth, value: isTextEditorFocused)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
    
    // MARK: - Bottom Actions
    
    @ViewBuilder
    private var bottomActions: some View {
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
            
            // Action buttons
            HStack(spacing: DesignSystem.Spacing.base) {
                Button("Cancel") {
                    withAnimation(DesignSystem.Animation.cozySettle) {
                        if let onCancel = onCancel {
                            onCancel()
                        } else {
                            dismiss()
                        }
                    }
                }
                .gemiSecondaryButton()
                .keyboardShortcut(.escape)
                
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
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(DesignSystem.Spacing.large)
        .background(
            Rectangle()
                .fill(DesignSystem.Colors.backgroundSecondary.opacity(0.5))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(DesignSystem.Colors.divider.opacity(0.3))
                        .frame(height: 1)
                }
        )
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
        
        isWriting = !newValue.isEmpty
        
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
            
            if let onSave = onSave {
                onSave()
            } else {
                dismiss()
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

#Preview("Floating Compose") {
    FloatingComposeView(entry: .constant(nil))
        .frame(width: 800, height: 600)
        .environment(try! JournalStore())
}