#!/usr/bin/env swift

// Test script to debug ResizableTextEditor visibility issues
// This script creates a minimal test window to isolate the problem

import SwiftUI
import AppKit

// Minimal ResizableTextEditor reproduction
struct TestResizableTextEditor: NSViewRepresentable {
    @Binding var text: String
    
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
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 15)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        // Critical fixes for text visibility
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        
        // Configure text container
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        // Disable auto-substitutions
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        print("🔍 Initial Setup:")
        print("  Text Color: \(textView.textColor ?? NSColor.clear)")
        print("  Background Color: \(textView.backgroundColor ?? NSColor.clear)")
        print("  Insertion Point Color: \(textView.insertionPointColor)")
        print("  Font: \(textView.font?.description ?? "nil")")
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Always update text color
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        
        if textView.string != text {
            textView.string = text
        }
        
        // Force text attributes
        if let textStorage = textView.textStorage {
            let range = NSRange(location: 0, length: textStorage.length)
            textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
            textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15), range: range)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: TestResizableTextEditor
        
        init(_ parent: TestResizableTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            
            // Ensure text color during typing
            textView.textColor = NSColor.labelColor
            
            // Apply attributes to new text
            if let textStorage = textView.textStorage {
                let range = NSRange(location: 0, length: textStorage.length)
                textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
                
                print("📝 Text Changed:")
                print("  Text Length: \(textStorage.length)")
                print("  Text Color: \(textView.textColor ?? NSColor.clear)")
                print("  Applied Attributes: foregroundColor = labelColor")
            }
        }
    }
}

// Test view with different backgrounds
struct TestView: View {
    @State private var text = ""
    @State private var backgroundColor = Color.white
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ResizableTextEditor Test")
                .font(.title)
            
            Text("Current text: \"\(text)\"")
                .foregroundColor(.secondary)
            
            // Test with different backgrounds
            VStack(spacing: 10) {
                Text("Test 1: White Background")
                TestResizableTextEditor(text: $text)
                    .frame(height: 60)
                    .background(Color.white)
                    .border(Color.gray)
                
                Text("Test 2: Secondary Background (0.99, 0.98, 0.96)")
                TestResizableTextEditor(text: $text)
                    .frame(height: 60)
                    .background(Color(red: 0.99, green: 0.98, blue: 0.96))
                    .border(Color.gray)
                
                Text("Test 3: Control Background")
                TestResizableTextEditor(text: $text)
                    .frame(height: 60)
                    .background(Color(NSColor.controlBackgroundColor))
                    .border(Color.gray)
                
                Text("Test 4: Clear Background")
                TestResizableTextEditor(text: $text)
                    .frame(height: 60)
                    .background(Color.clear)
                    .border(Color.gray)
            }
            .padding()
            
            // Color picker to test different backgrounds
            ColorPicker("Background Color:", selection: $backgroundColor)
            
            TestResizableTextEditor(text: $text)
                .frame(height: 60)
                .background(backgroundColor)
                .border(Color.gray)
        }
        .padding()
        .frame(width: 600, height: 600)
    }
}

// Create and run test window
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "ResizableTextEditor Test"
        window.contentView = NSHostingView(rootView: TestView())
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Run the app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()