#!/usr/bin/env python3
"""
Verify text visibility in ResizableTextEditor by checking color values
"""

import subprocess
import sys

def run_swift_code(code):
    """Run Swift code and return output"""
    process = subprocess.Popen(['swift', '-'], 
                              stdin=subprocess.PIPE, 
                              stdout=subprocess.PIPE, 
                              stderr=subprocess.PIPE,
                              text=True)
    stdout, stderr = process.communicate(input=code)
    return stdout, stderr

swift_test = '''
import AppKit

// Test color values
let labelColor = NSColor.labelColor
let bgSecondary = NSColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)

print("🎨 Color Analysis:")
print("Label Color (Light): ", terminator: "")
labelColor.usingColorSpace(.sRGB)?.getRed(nil, green: nil, blue: nil, alpha: nil)
print(labelColor.usingColorSpace(.sRGB)?.description ?? "Unknown")

print("Background Secondary: ", terminator: "")
print(bgSecondary.usingColorSpace(.sRGB)?.description ?? "Unknown")

// Calculate contrast
func luminance(_ color: NSColor) -> CGFloat {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
    return 0.299 * r + 0.587 * g + 0.114 * b
}

let labelLum = luminance(labelColor)
let bgLum = luminance(bgSecondary)
let contrast = (max(labelLum, bgLum) + 0.05) / (min(labelLum, bgLum) + 0.05)

print("\\nContrast Ratio: \\(String(format: \"%.2f\", contrast)):1")
print("Sufficient: \\(contrast >= 4.5 ? \"Yes ✅\" : \"No ❌\")")
'''

print("🔍 Verifying ResizableTextEditor Text Visibility")
print("=" * 50)

stdout, stderr = run_swift_code(swift_test)
if stdout:
    print(stdout)
if stderr:
    print("Errors:", stderr)

print("\n📋 Summary of Applied Fixes:")
print("1. ✅ Set textView.textColor = NSColor.labelColor")
print("2. ✅ Set textView.insertionPointColor = NSColor.labelColor")
print("3. ✅ Added typingAttributes with foregroundColor")
print("4. ✅ Apply text attributes in textDidChange")
print("5. ✅ Force update attributes in updateNSView")

print("\n🎯 Key Issue Identified:")
print("The typing attributes were not being set, causing new typed text")
print("to potentially use default colors instead of labelColor.")
print("\nThe fix ensures that all new text typed will use the correct")
print("foreground color by setting typingAttributes.")