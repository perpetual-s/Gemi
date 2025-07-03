#!/usr/bin/env xcrun swift

import SwiftUI
import AppKit

// Debug version of ResizableTextEditor with extensive logging
struct DebugResizableTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    @FocusState.Binding var isFocused: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        print("🔵 DEBUG: makeNSView called")
        
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
        
        // Debug: Log initial colors
        print("🔵 DEBUG: Setting initial colors...")
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        
        // Force explicit text color that's always visible
        let textColor = NSColor.black // Force black text
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        
        print("🔵 DEBUG: Text color set to: \(textColor)")
        print("🔵 DEBUG: Background color: \(textView.backgroundColor ?? NSColor.clear)")
        print("🔵 DEBUG: Draws background: \(textView.drawsBackground)")
        
        // Set font
        textView.font = .systemFont(ofSize: 15)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        // Configure text container
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        // Disable auto-replacements
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // Force typing attributes
        let typingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: textColor
        ]
        textView.typingAttributes = typingAttributes
        
        print("🔵 DEBUG: Typing attributes: \(typingAttributes)")
        
        // Add debug border to see if text view is visible
        textView.wantsLayer = true
        textView.layer?.borderWidth = 1
        textView.layer?.borderColor = NSColor.red.cgColor
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { 
            print("🔴 ERROR: Could not get textView from scrollView")
            return 
        }
        
        print("🔵 DEBUG: updateNSView called")
        print("🔵 DEBUG: Current text: '\(text)'")
        print("🔵 DEBUG: Current appearance: \(NSApp.effectiveAppearance.name)")
        
        // Force black text color
        let textColor = NSColor.black
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        
        // Update text if needed
        if textView.string != text {
            print("🔵 DEBUG: Updating text from '\(textView.string)' to '\(text)'")
            textView.string = text
            
            // Force text attributes on all text
            if let textStorage = textView.textStorage {
                let range = NSRange(location: 0, length: textStorage.length)
                textStorage.addAttribute(.foregroundColor, value: textColor, range: range)
                textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15), range: range)
                
                print("🔵 DEBUG: Applied attributes to range: \(range)")
                
                // Verify the attributes were applied
                if textStorage.length > 0 {
                    let attributes = textStorage.attributes(at: 0, effectiveRange: nil)
                    print("🔵 DEBUG: Verified attributes at position 0: \(attributes)")
                }
            }
            
            updateHeight(textView)
        }
        
        // Update focus
        if isFocused && textView.window?.firstResponder != textView {
            textView.window?.makeFirstResponder(textView)
        }
        
        // Ensure typing attributes are maintained
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: textColor
        ]
        
        // Debug: Check actual rendered color
        if let actualTextColor = textView.textColor {
            print("🔵 DEBUG: Actual text color: \(actualTextColor)")
            print("🔵 DEBUG: Text color components: R:\(actualTextColor.redComponent) G:\(actualTextColor.greenComponent) B:\(actualTextColor.blueComponent) A:\(actualTextColor.alphaComponent)")
        }
        
        // Debug: Check background
        if let backgroundColor = textView.backgroundColor {
            print("🔵 DEBUG: Background color: \(backgroundColor)")
            print("🔵 DEBUG: Background components: R:\(backgroundColor.redComponent) G:\(backgroundColor.greenComponent) B:\(backgroundColor.blueComponent) A:\(backgroundColor.alphaComponent)")
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
        let textHeight = usedRect.height
        let totalHeight = textHeight + textView.textContainerInset.height * 2
        
        DispatchQueue.main.async {
            height = max(40, min(totalHeight, 120))
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: DebugResizableTextEditor
        
        init(_ parent: DebugResizableTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            print("🔵 DEBUG: textDidChange called")
            print("🔵 DEBUG: New text: '\(textView.string)'")
            
            parent.text = textView.string
            parent.updateHeight(textView)
            
            // Force black text color
            let textColor = NSColor.black
            textView.textColor = textColor
            
            // Apply attributes to maintain visibility
            if let textStorage = textView.textStorage {
                let range = NSRange(location: 0, length: textStorage.length)
                textStorage.addAttribute(.foregroundColor, value: textColor, range: range)
                
                print("🔵 DEBUG: Applied text color to range: \(range)")
            }
            
            // Ensure typing attributes for new text
            textView.typingAttributes = [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: textColor
            ]
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            print("🔵 DEBUG: doCommandBy: \(commandSelector)")
            return false
        }
    }
}

// Test harness
struct TestView: View {
    @State private var text = ""
    @State private var height: CGFloat = 40
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("NSTextView Debug Test")
                .font(.largeTitle)
            
            // Test 1: Basic NSTextView
            VStack(alignment: .leading) {
                Text("Test 1: Debug NSTextView (forced black text)")
                DebugResizableTextEditor(
                    text: $text,
                    height: $height,
                    isFocused: $isFocused
                )
                .frame(height: height)
                .background(Color.white)
                .border(Color.blue, width: 2)
            }
            
            // Test 2: With forced light environment (mimicking ChatView)
            VStack(alignment: .leading) {
                Text("Test 2: With forced light environment")
                DebugResizableTextEditor(
                    text: $text,
                    height: $height,
                    isFocused: $isFocused
                )
                .frame(height: height)
                .background(Color(red: 0.99, green: 0.98, blue: 0.96)) // DesignSystem.Colors.backgroundSecondary
                .border(Color.green, width: 2)
                .environment(\.colorScheme, .light)
            }
            
            // Display current text
            Text("Current text: '\(text)'")
                .padding()
                .background(Color.gray.opacity(0.2))
            
            Spacer()
        }
        .padding()
        .frame(width: 600, height: 500)
    }
}

// Run the test
NSApplication.shared.run {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.center()
    window.title = "NSTextView Debug Test"
    window.contentView = NSHostingView(rootView: TestView())
    window.makeKeyAndOrderFront(nil)
}

// Helper extension
extension NSApplication {
    func run<V: View>(@ViewBuilder view: () -> V) {
        let delegate = AppDelegate(view())
        NSApp.setActivationPolicy(.regular)
        NSApp.delegate = delegate
        NSApp.activate(ignoringOtherApps: true)
        NSApp.run()
    }
}

class AppDelegate<V: View>: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var hostingView: V?
    
    init(_ view: V) {
        self.hostingView = view
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Window is created in run()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}