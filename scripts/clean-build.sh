#!/bin/bash

# Clean Build Script for Gemi
# This ensures no old server artifacts remain in the build

echo "🧹 Cleaning Gemi build artifacts..."

# Remove all build directories
echo "→ Removing build directories..."
rm -rf /Users/chaeho/Documents/project-Gemi/build
rm -rf /Users/chaeho/Documents/project-Gemi/Gemi/build
rm -rf /Users/chaeho/Library/Developer/Xcode/DerivedData/Gemi-*

# Remove any old archives
echo "→ Removing old archives..."
rm -rf /Users/chaeho/Documents/project-Gemi/*.xcarchive

# Clean Xcode's module cache for good measure
echo "→ Cleaning module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex

echo "✅ Clean complete!"
echo ""
echo "Next steps:"
echo "1. Open Gemi.xcodeproj in Xcode"
echo "2. Product → Clean Build Folder (Shift+Cmd+K)"
echo "3. Product → Build (Cmd+B)"
echo "4. Test the app to ensure no server window appears"
echo ""
echo "For release build:"
echo "5. Product → Archive"
echo "6. Run create-dmg.sh to create the distribution DMG"