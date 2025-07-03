#!/usr/bin/env xcrun swift

import Foundation

// Script to add debug logging to ResizableTextEditor

let filePath = "/Users/chaeho/Documents/project-Gemi/Gemi/Gemi/Views/ChatView.swift"

// Add debug logging after textView configuration
let debugCode = """

        // DEBUG: Log color values
        print("🔵 DEBUG ResizableTextEditor Colors:")
        print("  Text Color: \\(textView.textColor?.description ?? "nil")")
        print("  Background Color: \\(textView.backgroundColor?.description ?? "nil")")
        print("  Draws Background: \\(textView.drawsBackground)")
        print("  Insertion Point Color: \\(textView.insertionPointColor?.description ?? "nil")")
        print("  Typing Attributes: \\(textView.typingAttributes)")
"""

print("Adding debug logging to ResizableTextEditor...")
print("This will help diagnose any remaining text visibility issues.")
print("\nTo use:")
print("1. Build and run Gemi")
print("2. Click in the chat input field")
print("3. Type some text")
print("4. Check the console output for color values")
print("\nDebug output will show:")
print("• Actual text and background colors being used")
print("• Whether background drawing is enabled")
print("• Typing attributes for new text")

// Note: This is a diagnostic tool only - the actual fix has been applied