//
//  JournalEditorView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI
import AppKit

/// A premium journal editor that feels like writing in a beautiful notebook
struct JournalEditorView: View {
    
    // MARK: - Properties
    
    @Binding var entry: JournalEntry?
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isTypewriterMode: Bool = false
    @State private var isFocusMode: Bool = false
    @State private var selectedRange: NSRange?
    @State private var showingToolbar: Bool = false
    @State private var toolbarPosition: CGPoint = .zero
    @State private var wordCount: Int = 0
    @State private var lastSaved: Date = Date()
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditorFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background with subtle paper texture
            paperBackground
            
            // Main content
            if isFocusMode {
                focusModeView
            } else {
                normalModeView
            }
            
            // Floating toolbar
            if showingToolbar && selectedRange != nil {
                floatingToolbar
                    .position(toolbarPosition)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)),
                        removal: .opacity
                    ))
            }
        }
        .onAppear {
            if let entry = entry {
                title = entry.title
                content = entry.content
            }
            isEditorFocused = true
        }
    }
    
    // MARK: - Paper Background
    
    @ViewBuilder
    private var paperBackground: some View {
        ZStack {
            // Base color
            Color(red: 0.99, green: 0.98, blue: 0.97)
            
            // Subtle paper texture
            Canvas { context, size in
                // Create subtle noise pattern
                for _ in 0..<500 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let opacity = Double.random(in: 0.02...0.04)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.gray.opacity(opacity))
                    )
                }
            }
            .allowsHitTesting(false)
            
            // Very subtle horizontal lines (like notebook paper)
            GeometryReader { geometry in
                VStack(spacing: 28) {
                    ForEach(0..<100, id: \.self) { _ in
                        Divider()
                            .opacity(0.03)
                    }
                }
            }
        }
    }
    
    // MARK: - Normal Mode View
    
    @ViewBuilder
    private var normalModeView: some View {
        VStack(spacing: 0) {
            // Header
            editorHeader
            
            Divider()
                .opacity(0.1)
            
            // Editor content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title field
                    titleField
                    
                    // Content editor
                    contentEditor
                        .padding(.bottom, 100)
                }
                .padding(.horizontal, editorPadding)
                .padding(.top, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            
            // Bottom toolbar
            bottomToolbar
        }
    }
    
    // MARK: - Focus Mode View
    
    @ViewBuilder
    private var focusModeView: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 200)
                        
                        // Content editor centered
                        VStack(alignment: .leading, spacing: 24) {
                            titleField
                                .id("editor")
                            
                            contentEditor
                        }
                        .padding(.horizontal, editorPadding)
                        .frame(maxWidth: 700)
                        
                        Spacer(minLength: 300)
                    }
                    .onChange(of: content) { _, _ in
                        if isTypewriterMode {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo("editor", anchor: .center)
                            }
                        }
                    }
                }
            }
            
            // Exit focus mode button
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isFocusMode = false
                        }
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(.regularMaterial)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(0.6)
                    .padding(24)
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Editor Components
    
    @ViewBuilder
    private var editorHeader: some View {
        HStack(spacing: 16) {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(entry?.createdAt ?? Date(), style: .date)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                
                Text(entry?.createdAt ?? Date(), style: .time)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Mode toggles
            HStack(spacing: 8) {
                // Typewriter mode
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isTypewriterMode.toggle()
                    }
                } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isTypewriterMode ? .white : .secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(isTypewriterMode ? Color.primary : Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Typewriter mode")
                
                // Focus mode
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isFocusMode = true
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Focus mode")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(red: 0.99, green: 0.98, blue: 0.97))
    }
    
    @ViewBuilder
    private var titleField: some View {
        TextField("Untitled", text: $title, axis: .vertical)
            .font(.system(size: 32, weight: .semibold, design: .serif))
            .foregroundStyle(.primary)
            .textFieldStyle(.plain)
            .focused($isEditorFocused)
    }
    
    @ViewBuilder
    private var contentEditor: some View {
        PremiumTextEditor(
            text: $content,
            selectedRange: $selectedRange,
            onSelectionChange: { range, rect in
                if let range = range, range.length > 0 {
                    showingToolbar = true
                    // Position toolbar above selection
                    toolbarPosition = CGPoint(
                        x: rect.midX,
                        y: rect.minY - 50
                    )
                } else {
                    showingToolbar = false
                }
            }
        )
        .onChange(of: content) { _, newValue in
            wordCount = newValue.split(separator: " ").count
            autoSave()
        }
    }
    
    @ViewBuilder
    private var bottomToolbar: some View {
        HStack(spacing: 24) {
            // Word count
            HStack(spacing: 4) {
                Text("\(wordCount)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("words")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Divider()
                .frame(height: 16)
                .opacity(0.2)
            
            // Last saved
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                
                Text("Saved")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(lastSaved, style: .relative)
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(red: 0.98, green: 0.97, blue: 0.96))
                .overlay(alignment: .top) {
                    Divider()
                        .opacity(0.1)
                }
        )
    }
    
    // MARK: - Floating Toolbar
    
    @ViewBuilder
    private var floatingToolbar: some View {
        HStack(spacing: 2) {
            FormatButton(icon: "bold", action: { applyFormat(.bold) })
            FormatButton(icon: "italic", action: { applyFormat(.italic) })
            FormatButton(icon: "underline", action: { applyFormat(.underline) })
            
            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)
            
            FormatButton(icon: "link", action: { applyFormat(.link) })
            FormatButton(icon: "quote.opening", action: { applyFormat(.quote) })
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 4)
        )
    }
    
    // MARK: - Helper Properties
    
    private var editorPadding: CGFloat {
        isFocusMode ? 60 : 80
    }
    
    // MARK: - Methods
    
    private func applyFormat(_ format: TextFormat) {
        // Format implementation
    }
    
    private func autoSave() {
        // Auto-save implementation
        lastSaved = Date()
    }
}

// MARK: - Text Format

enum TextFormat {
    case bold, italic, underline, link, quote
}

// MARK: - Format Button

struct FormatButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Premium Text Editor

struct PremiumTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange?
    let onSelectionChange: (NSRange?, CGRect) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        
        // Typography settings
        textView.font = NSFont.systemFont(ofSize: 17, weight: .regular)
        textView.textColor = NSColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1.0)
        
        // Line spacing for comfortable reading
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.7
        textView.defaultParagraphStyle = paragraphStyle
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: PremiumTextEditor
        
        init(_ parent: PremiumTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            let range = textView.selectedRange()
            parent.selectedRange = range
            
            if range.length > 0 {
                let glyphRange = textView.layoutManager?.glyphRange(forCharacterRange: range, actualCharacterRange: nil) ?? range
                let rect = textView.layoutManager?.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer!) ?? .zero
                let screenRect = textView.convert(rect, to: nil)
                parent.onSelectionChange(range, screenRect)
            } else {
                parent.onSelectionChange(nil, .zero)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    JournalEditorView(entry: .constant(JournalEntry(
        title: "A Beautiful Day",
        content: "Today was absolutely wonderful. The sun was shining, birds were singing, and I felt a deep sense of peace and contentment."
    )))
    .frame(width: 900, height: 700)
}