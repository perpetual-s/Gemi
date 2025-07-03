// NUCLEAR OPTION: Replace ResizableTextEditor with SwiftUI TextField
// This guarantees text visibility but loses some features

import SwiftUI

// Option 1: Simple TextField replacement
struct SimpleTextInput: View {
    @Binding var text: String
    let onSend: () -> Void
    let onVoice: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Text input with guaranteed visibility
            HStack(alignment: .center, spacing: 8) {
                TextField("Type a message...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .lineLimit(1...5) // Allow up to 5 lines
                    .focused($isFocused)
                    .onSubmit {
                        if !text.isEmpty {
                            onSend()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                
                // Voice button
                Button(action: onVoice) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
            
            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [Color(red: 0.36, green: 0.61, blue: 0.84), 
                                        Color(red: 0.42, green: 0.67, blue: 0.88)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty)
            .opacity(text.isEmpty ? 0.5 : 1.0)
        }
        .padding(16)
        .onAppear {
            isFocused = true
        }
    }
}

// Option 2: Enhanced NSTextView with guaranteed visibility
struct GuaranteedVisibleTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    @FocusState.Binding var isFocused: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // NUCLEAR OPTIONS - Override everything
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white // Force white background
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.backgroundColor = .white // Force white
        textView.drawsBackground = true
        textView.font = .systemFont(ofSize: 15)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        // NUCLEAR: Force black text on white background
        textView.textColor = .black
        textView.insertionPointColor = .black
        
        // NUCLEAR: Set ALL text attributes
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.black,
            .backgroundColor: NSColor.white
        ]
        
        // NUCLEAR: Override appearance
        textView.appearance = NSAppearance(named: .aqua) // Force light mode
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // NUCLEAR: Force colors on every update
        textView.textColor = .black
        textView.backgroundColor = .white
        textView.insertionPointColor = .black
        
        if textView.string != text {
            textView.string = text
            updateHeight(textView)
        }
        
        // NUCLEAR: Force text attributes on all text
        if let textStorage = textView.textStorage {
            let range = NSRange(location: 0, length: textStorage.length)
            textStorage.addAttribute(.foregroundColor, value: NSColor.black, range: range)
            textStorage.addAttribute(.backgroundColor, value: NSColor.white, range: range)
            textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15), range: range)
        }
        
        // NUCLEAR: Reset typing attributes
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.black,
            .backgroundColor: NSColor.white
        ]
        
        if isFocused && textView.window?.firstResponder != textView {
            textView.window?.makeFirstResponder(textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updateHeight(_ textView: NSTextView) {
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager else { return }
        
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let totalHeight = usedRect.height + textView.textContainerInset.height * 2
        
        DispatchQueue.main.async {
            height = max(40, min(totalHeight, 120))
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: GuaranteedVisibleTextEditor
        
        init(_ parent: GuaranteedVisibleTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.updateHeight(textView)
            
            // NUCLEAR: Force black text on every change
            textView.textColor = .black
            textView.backgroundColor = .white
            
            if let textStorage = textView.textStorage {
                let range = NSRange(location: 0, length: textStorage.length)
                textStorage.addAttribute(.foregroundColor, value: NSColor.black, range: range)
                textStorage.addAttribute(.backgroundColor, value: NSColor.white, range: range)
            }
            
            textView.typingAttributes = [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.black,
                .backgroundColor: NSColor.white
            ]
        }
    }
}