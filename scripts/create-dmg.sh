#!/bin/bash

# Gemi DMG Creator - Beautiful Installer with Drag & Drop
# Build in Xcode (Cmd+B), then run this script

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🎨 Gemi DMG Creator${NC}"
echo "===================="

# Find Gemi.app
echo -e "${BLUE}Finding Gemi.app...${NC}"
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Gemi.app" -type d 2>/dev/null | head -1)

if [[ ! -d "$APP" ]]; then
    echo -e "${RED}❌ Gemi.app not found!${NC}"
    echo "Build in Xcode first (Cmd+B)"
    exit 1
fi

echo -e "${GREEN}✓ Found${NC}"

# Setup paths
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="$PROJECT_ROOT/Gemi.dmg"
VOLUME_NAME="Gemi"
BACKGROUND="$PROJECT_ROOT/Documentation/assets/dmg-background-clean-premium.png"

# Check for create-dmg
if command -v create-dmg &> /dev/null; then
    echo -e "${BLUE}Creating beautiful DMG with background...${NC}"
    
    # Clean up
    rm -f "$DMG_PATH"
    
    # Use create-dmg for the best result
    create-dmg \
        --volname "$VOLUME_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "Gemi.app" 150 200 \
        --hide-extension "Gemi.app" \
        --app-drop-link 450 200 \
        --background "$BACKGROUND" \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP"
    
    SUCCESS=$?
else
    echo -e "${BLUE}Installing create-dmg for beautiful DMGs...${NC}"
    
    # Try to install create-dmg
    if command -v brew &> /dev/null; then
        brew install create-dmg
        
        # Try again with create-dmg
        if command -v create-dmg &> /dev/null; then
            rm -f "$DMG_PATH"
            create-dmg \
                --volname "$VOLUME_NAME" \
                --window-pos 200 120 \
                --window-size 600 400 \
                --icon-size 100 \
                --icon "Gemi.app" 150 200 \
                --hide-extension "Gemi.app" \
                --app-drop-link 450 200 \
                --background "$BACKGROUND" \
                --no-internet-enable \
                "$DMG_PATH" \
                "$APP"
            SUCCESS=$?
        else
            SUCCESS=1
        fi
    else
        echo "Homebrew not found. Install from https://brew.sh"
        SUCCESS=1
    fi
fi

# Fallback method if create-dmg isn't available
if [[ $SUCCESS -ne 0 ]]; then
    echo -e "${BLUE}Using manual method...${NC}"
    
    # Create temp directory
    TEMP_DIR="/tmp/gemi-dmg-$$"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR/.background"
    
    # Copy files
    cp -R "$APP" "$TEMP_DIR/"
    ln -s /Applications "$TEMP_DIR/Applications"
    
    if [[ -f "$BACKGROUND" ]]; then
        cp "$BACKGROUND" "$TEMP_DIR/.background/background.png"
    fi
    
    # Create DMG
    rm -f "$DMG_PATH"
    
    # Create temporary DMG
    TEMP_DMG="/tmp/gemi-temp-$$.dmg"
    hdiutil create -size 150m -fs HFS+ -volname "$VOLUME_NAME" "$TEMP_DMG"
    
    # Mount it
    DEVICE=$(hdiutil attach -readwrite -noverify "$TEMP_DMG" | egrep '^/dev/' | sed 1q | awk '{print $1}')
    MOUNT="/Volumes/$VOLUME_NAME"
    
    # Copy everything
    cp -R "$TEMP_DIR"/* "$MOUNT/"
    cp -R "$TEMP_DIR"/.background "$MOUNT/" 2>/dev/null || true
    
    # Try to set window properties
    echo '
       tell application "Finder"
         tell disk "'"$VOLUME_NAME"'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set bounds of container window to {200, 100, 800, 500}
           set viewOptions to icon view options of container window
           set arrangement of viewOptions to not arranged
           set icon size of viewOptions to 100
           try
             set background picture of viewOptions to file ".background:background.png"
           end try
           update without registering applications
           delay 2
           close
         end tell
       end tell
    ' | osascript
    
    # Unmount
    sync
    hdiutil detach "$DEVICE" -quiet
    
    # Convert to compressed
    hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_PATH" -quiet
    
    # Clean up
    rm -f "$TEMP_DMG"
    rm -rf "$TEMP_DIR"
fi

# Show result
if [[ -f "$DMG_PATH" ]]; then
    SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo ""
    echo -e "${GREEN}✨ Success!${NC}"
    echo -e "📦 Created: ${BLUE}Gemi.dmg${NC} (${SIZE})"
    echo ""
    echo "DMG contains:"
    echo "  • Gemi.app"
    echo "  • Applications shortcut (drag & drop to install)"
    if [[ -f "$BACKGROUND" ]]; then
        echo "  • Beautiful background"
    fi
    echo ""
    echo "Opening DMG..."
    open "$DMG_PATH"
else
    echo -e "${RED}❌ Failed to create DMG${NC}"
    exit 1
fi