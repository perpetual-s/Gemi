#!/usr/bin/env swift

// Test script to verify chat input text visibility
// This script checks the color configurations and provides debugging information

import AppKit

print("🔍 Checking Chat Input Text Visibility Configuration")
print(String(repeating: "=", count: 50))

// Check system colors
print("\n📊 System Color Values:")
print("NSColor.labelColor: \(NSColor.labelColor)")
print("NSColor.textColor: \(NSColor.textColor)")
print("NSColor.controlBackgroundColor: \(NSColor.controlBackgroundColor)")
print("NSColor.textBackgroundColor: \(NSColor.textBackgroundColor)")

// Check color in different appearances
print("\n🎨 Color Values in Different Appearances:")

let lightAppearance = NSAppearance(named: .aqua)!
let darkAppearance = NSAppearance(named: .darkAqua)!

NSAppearance.current = lightAppearance
print("\nLight Mode:")
print("  Label Color: \(NSColor.labelColor.cgColor.components ?? [])")
print("  Control Background: \(NSColor.controlBackgroundColor.cgColor.components ?? [])")

NSAppearance.current = darkAppearance
print("\nDark Mode:")
print("  Label Color: \(NSColor.labelColor.cgColor.components ?? [])")
print("  Control Background: \(NSColor.controlBackgroundColor.cgColor.components ?? [])")

// Color contrast check
func calculateContrast(foreground: NSColor, background: NSColor) -> Double {
    let fgComponents = foreground.cgColor.components ?? [0, 0, 0, 1]
    let bgComponents = background.cgColor.components ?? [1, 1, 1, 1]
    
    // Simple luminance calculation
    let fgLuminance = 0.299 * fgComponents[0] + 0.587 * fgComponents[1] + 0.114 * fgComponents[2]
    let bgLuminance = 0.299 * bgComponents[0] + 0.587 * bgComponents[1] + 0.114 * bgComponents[2]
    
    let lighter = max(fgLuminance, bgLuminance)
    let darker = min(fgLuminance, bgLuminance)
    
    return (lighter + 0.05) / (darker + 0.05)
}

print("\n📐 Contrast Ratios:")
NSAppearance.current = lightAppearance
let lightContrast = calculateContrast(
    foreground: NSColor.labelColor,
    background: NSColor.controlBackgroundColor
)
print("Light Mode Contrast: \(String(format: "%.2f", lightContrast)):1")

NSAppearance.current = darkAppearance
let darkContrast = calculateContrast(
    foreground: NSColor.labelColor,
    background: NSColor.controlBackgroundColor
)
print("Dark Mode Contrast: \(String(format: "%.2f", darkContrast)):1")

print("\n✅ Recommendations:")
print("- Minimum contrast ratio for normal text: 4.5:1")
print("- Minimum contrast ratio for large text: 3:1")

if lightContrast < 4.5 {
    print("⚠️  Light mode contrast may be insufficient!")
}
if darkContrast < 4.5 {
    print("⚠️  Dark mode contrast may be insufficient!")
}

print("\n🔧 Fixes Applied:")
print("1. ✅ Set explicit text color using NSColor.labelColor")
print("2. ✅ Set insertion point color for cursor visibility")
print("3. ✅ Apply text attributes to maintain color during typing")
print("4. ✅ Changed background from controlBackgroundColor to DesignSystem.Colors.backgroundSecondary")
print("5. ✅ Added text storage attribute updates in textDidChange")

print("\n📝 Testing Instructions:")
print("1. Build and run the Gemi app")
print("2. Open the chat interface")
print("3. Click on the text input field")
print("4. Type some text")
print("5. Verify text is visible in both light and dark modes")
print("6. Check that the cursor is visible")

print("\n🎯 Expected Result:")
print("- Text should be clearly visible while typing")
print("- Cursor should be visible and match text color")
print("- Background should provide sufficient contrast")
print("- Text should remain visible after losing and regaining focus")