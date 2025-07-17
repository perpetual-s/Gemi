#!/bin/bash

# Gemi DMG Creator - Simple & Reliable Version

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FINAL_DMG="$PROJECT_ROOT/Gemi-Installer.dmg"

echo "🎨 Gemi DMG Creator"
echo "==================="

# Find Gemi.app
echo "📱 Looking for Gemi.app..."
APP=""

# Check DerivedData first
DERIVED_DATA_APP=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "Gemi.app" -type d 2>/dev/null | head -1)
if [[ -n "$DERIVED_DATA_APP" ]] && [[ -d "$DERIVED_DATA_APP" ]]; then
    APP="$DERIVED_DATA_APP"
    echo "✅ Found: $APP"
else
    # Try to build
    echo "⚠️  No existing build found. Building..."
    cd "$PROJECT_ROOT/Gemi"
    xcodebuild -scheme Gemi -configuration Release build
    
    # Find the built app
    APP=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "Gemi.app" -type d 2>/dev/null | head -1)
    if [[ -z "$APP" ]] || [[ ! -d "$APP" ]]; then
        echo "❌ Build failed!"
        exit 1
    fi
fi

# Verify app exists
if [[ ! -d "$APP/Contents" ]]; then
    echo "❌ Invalid app bundle: $APP"
    exit 1
fi

# Get app size
APP_SIZE=$(du -sh "$APP" | cut -f1)
echo "📏 App size: $APP_SIZE"

# Create DMG
echo "💿 Creating DMG..."

# Clean up old DMG
rm -f "$FINAL_DMG"

# Create DMG using hdiutil
echo "   Creating disk image..."
hdiutil create -volname "Gemi" \
    -srcfolder "$APP" \
    -ov \
    -format UDZO \
    "$FINAL_DMG"

# Verify DMG
if [[ -f "$FINAL_DMG" ]]; then
    DMG_SIZE=$(du -h "$FINAL_DMG" | cut -f1)
    echo ""
    echo "✅ Success!"
    echo "📦 DMG created: $FINAL_DMG"
    echo "📏 Size: $DMG_SIZE"
    echo ""
    echo "Opening in Finder..."
    open -R "$FINAL_DMG"
else
    echo "❌ Failed to create DMG!"
    exit 1
fi