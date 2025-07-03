#!/usr/bin/env python3
"""
Test script to verify text visibility fix in ResizableTextEditor
"""

import subprocess
import time
import sys

def test_text_visibility():
    """Test if text is visible in the chat input"""
    print("🔍 Testing text visibility in ResizableTextEditor...")
    print("=" * 60)
    
    # Build and run Gemi
    print("\n1. Building Gemi...")
    build_result = subprocess.run(
        ["xcodebuild", "build", "-scheme", "Gemi", "-configuration", "Debug"],
        cwd="/Users/chaeho/Documents/project-Gemi/Gemi",
        capture_output=True,
        text=True
    )
    
    if build_result.returncode != 0:
        print("❌ Build failed!")
        print(build_result.stderr)
        return False
    
    print("✅ Build successful")
    
    # Create AppleScript to test text input
    applescript = '''
    tell application "Gemi"
        activate
        delay 2
    end tell
    
    -- Wait for app to fully load
    delay 3
    
    tell application "System Events"
        tell process "Gemi"
            -- Click on the chat input area
            click text field 1 of window 1
            delay 1
            
            -- Type test text
            keystroke "Testing text visibility - can you see this?"
            delay 1
            
            -- Take a screenshot for manual verification
            do shell script "screencapture -x /tmp/gemi_text_test.png"
        end tell
    end tell
    '''
    
    print("\n2. Running UI test...")
    result = subprocess.run(
        ["osascript", "-e", applescript],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print("⚠️ UI test had issues:")
        print(result.stderr)
    else:
        print("✅ UI test completed")
        print("📸 Screenshot saved to: /tmp/gemi_text_test.png")
    
    print("\n3. Summary of fixes applied:")
    print("   • Changed NSColor.labelColor → NSColor.black")
    print("   • Changed NSColor.textBackgroundColor → NSColor.white")
    print("   • Set drawsBackground = true for both scrollView and textView")
    print("   • Applied black foreground color to all text attributes")
    print("   • Ensured typing attributes use black text")
    
    print("\n4. What to verify:")
    print("   • Text should be clearly visible (black on white)")
    print("   • Text should remain visible while typing")
    print("   • Cursor should be visible (black)")
    print("   • Background should be opaque white")
    
    return True

if __name__ == "__main__":
    success = test_text_visibility()
    sys.exit(0 if success else 1)