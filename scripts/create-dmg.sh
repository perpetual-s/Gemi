#!/bin/bash

# Create beautiful DMG with background - the right way

set -e

echo "✨ Gemi DMG Creator"

# Check for create-dmg tool
if ! command -v create-dmg &> /dev/null; then
    echo "📦 Installing create-dmg (one-time setup)..."
    brew install create-dmg
fi

# Find Gemi.app
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Gemi.app" -type d 2>/dev/null | grep -E "Debug|Release" | head -1)
if [ -z "$APP" ]; then
    echo "❌ Please build Gemi.app in Xcode first"
    exit 1
fi

echo "✅ Found: $APP"

# Paths
PROJECT_ROOT="$(dirname "$(dirname "$0")")"
BACKGROUND="$PROJECT_ROOT/Documentation/assets/dmg-background-clean-premium.png"
DMG="$PROJECT_ROOT/Gemi-Installer.dmg"

# Include .env if exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    cp "$PROJECT_ROOT/.env" "$APP/Contents/Resources/.env" 2>/dev/null || true
fi

# Remove old DMG
rm -f "$DMG"

# Create DMG with background
echo "🎨 Creating beautiful DMG..."
create-dmg \
    --volname "Gemi Installer" \
    --background "$BACKGROUND" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "Gemi.app" 150 200 \
    --hide-extension "Gemi.app" \
    --app-drop-link 450 200 \
    --no-internet-enable \
    "$DMG" \
    "$APP"

echo "✅ Done!"
echo "📍 $DMG"
open -R "$DMG"