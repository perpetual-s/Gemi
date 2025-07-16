#!/bin/bash

# Quick test script to verify DMG background image

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKGROUND="$PROJECT_ROOT/Documentation/assets/dmg-background-clean-premium.png"

echo "🔍 Checking DMG background setup..."
echo ""

# Check if background exists
if [ -f "$BACKGROUND" ]; then
    echo "✅ Background image found: $BACKGROUND"
    echo "   Size: $(du -h "$BACKGROUND" | cut -f1)"
    echo "   Type: $(file -b "$BACKGROUND")"
else
    echo "❌ Background image not found!"
    exit 1
fi

echo ""
echo "📝 Background info:"
echo "   - Size: 600x400 pixels"
echo "   - Premium gradient design"
echo "   - Located in Documentation/assets/"

echo ""
echo "🎨 To create a DMG with this background:"
echo "   cd scripts"
echo "   ./create-dmg.sh"

echo ""
echo "💡 Tips for best results:"
echo "   1. Make sure you have a Release build of Gemi.app"
echo "   2. The script will automatically find and use the background"
echo "   3. Icon positions are optimized for the 600x400 layout"
echo "   4. Background may not appear in Quick Look preview"
echo ""