#!/bin/bash

# Simple Gemi DMG Creation Script

set -e

echo "Creating Gemi DMG..."

# Paths
BUILD_DIR="/Users/chaeho/Library/Developer/Xcode/DerivedData/Gemi-gzhmrwuzvujrehgmrgxtydkgciay/Build/Products/Debug"
APP_PATH="$BUILD_DIR/Gemi.app"
DMG_PATH="Gemi.dmg"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Gemi.app not found. Please build in Xcode first."
    exit 1
fi

# Remove old DMG
rm -f "$DMG_PATH"

# Create DMG
echo "Creating DMG from $APP_PATH..."
hdiutil create -volname "Gemi" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Get size
SIZE=$(du -sh "$DMG_PATH" | cut -f1)

echo "✅ DMG created successfully!"
echo "Location: $(pwd)/$DMG_PATH"
echo "Size: $SIZE"